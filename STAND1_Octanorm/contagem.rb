# encoding: UTF-8
# =============================================================================
# STAND1 Octanorm — contagem.rb
# Lista de pecas: conta o que o plugin montou (paredes, salas, ilhas, tetos e
# portas) no modelo inteiro ou so no que estiver selecionado.
#   montante ........ por altura (2,90 / 2,20 / 0,70 da ilha / 0,175 do no do teto)
#   travessa e Z500 . por vao (1,00 / 0,50 / especial), com a medida da peca
#   folha TS, vidro, placa MDF ... por medida
#   spider .......... por numero de garras (1, 2 ou 4)
#   porta ........... Octanorm ou vidro
# Cada copia de parede conta (anda o modelo pelas instancias). Bloco da
# Biblioteca (ex.: stands prontos do FLASO) nao entra: so peca do plugin.
# =============================================================================
require 'json'

module STAND1
  module Octanorm
    module Contagem
      ATRIB = Geometria::ATRIB
      PLACAS = { "Octanorm TS Branco" => "Folha TS", "Octanorm Vidro" => "Vidro",
                 "Testeira MDF Branco" => "Placa MDF", "Forro Eucatex Branco" => "Forro eucatex" }.freeze
      ORDEM = ["Montante", "Travessa", "Z500", "Folha TS", "Vidro", "Placa MDF", "Forro eucatex", "Spider", "Porta"].freeze

      def self.cm_txt(v)
        v = (v.to_f * 2).round / 2.0 # meio cm
        v == v.to_i ? v.to_i.to_s : format("%.1f", v).tr(".", ",")
      end

      def self.m_txt(cm)
        s = format("%.3f", cm / 100.0).sub(/0\z/, "")
        s.tr(".", ",")
      end

      # comprimento da peca esticada: maior medida da definicao x escala da instancia
      def self.comprimento(defn, tr)
        b = defn.bounds
        dims = [b.width, b.height, b.depth]
        i = dims.index(dims.max)
        eixo = [X_AXIS, Y_AXIS, Z_AXIS][i].transform(tr)
        (dims[i] * eixo.length).to_cm
      end

      def self.contar(ents, model)
        @larg = nil
        mont = model.definitions.find { |d| d.get_attribute(ATRIB, "peca") == "montante" }
        @larg = Geometria.largura_montante(mont) if mont
        spider = model.definitions.find { |d| d.get_attribute(ATRIB, "peca") == "spider" }
        @bracos = spider ? Geometria.bracos(spider).map { |b| b[:defn] } : []
        itens = Hash.new(0)
        ents.each { |e| visitar(e, Geom::Transformation.new, itens, 0) }
        itens.map { |(grupo, peca, medida), n| { grupo: grupo, peca: peca, medida: medida, qtd: n } }
             .sort_by { |i| [ORDEM.index(i[:grupo]) || 99, i[:peca], i[:medida]] }
      end

      def self.vao_txt(cm)
        return "" unless @larg

        v = (cm + @larg).round
        { 100 => "vao 1,00", 50 => "vao 0,50" }[v] || "vao especial #{m_txt(v)}"
      end

      def self.visitar(e, tr, itens, nivel)
        return unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        return if nivel > 8

        t = tr * e.transformation
        d = e.definition
        peca = d.get_attribute(ATRIB, "peca")
        case peca
        when "montante"
          itens[["Montante", "Montante #{m_txt(comprimento(d, t).round(1))} m", ""]] += 1
          return
        when "travessa", "z500"
          c = comprimento(d, t)
          nome = peca == "z500" ? "Z500" : "Travessa"
          itens[[nome, "#{nome} (#{vao_txt(c)})", "#{cm_txt(c)} cm"]] += 1
          return
        when "porta_octanorm", "porta_vidro"
          itens[["Porta", peca == "porta_vidro" ? "Porta de vidro" : "Porta Octanorm", ""]] += 1
          return
        end
        if (g = e.get_attribute(ATRIB, "garras"))
          itens[["Spider", "Spider #{g} garra#{g.to_i > 1 ? 's' : ''}", ""]] += 1
          return
        end
        if @bracos.include?(d)
          itens[["Spider", "Garra de spider avulsa (parede de versao antiga)", ""]] += 1
          return
        end
        if e.is_a?(Sketchup::Group) && e.material && PLACAS[e.material.name]
          b = d.bounds
          # placa em pe (parede): largura x altura; deitada (forro): largura x profundidade
          lado = b.depth < b.height ? b.height : b.depth
          itens[[PLACAS[e.material.name], PLACAS[e.material.name], "#{cm_txt(b.width.to_cm)} x #{cm_txt(lado.to_cm)} cm"]] += 1
          return
        end
        d.entities.each { |x| visitar(x, t, itens, nivel + 1) }
      end

      # ---- janela -------------------------------------------------------------
      def self.abrir
        model = Sketchup.active_model
        sel = model.selection.to_a
        alvo = sel.empty? ? model.active_entities.to_a : sel
        itens = contar(alvo, model)
        @ultimo = { titulo: sel.empty? ? "Modelo inteiro" : "Selecao (#{sel.size} item#{sel.size > 1 ? 's' : ''})",
                    modelo: File.basename(model.path.to_s, ".skp"), itens: itens }
        if @dlg && @dlg.visible?
          enviar
          @dlg.bring_to_front
          return
        end
        @dlg = UI::HtmlDialog.new(dialog_title: "Lista de pecas Octanorm", preferences_key: "STAND1_Octanorm_pecas",
                                  width: 560, height: 640, min_width: 380, min_height: 300,
                                  style: UI::HtmlDialog::STYLE_DIALOG)
        @dlg.set_file(File.join(__dir__, "html", "pecas.html"))
        @dlg.add_action_callback("pronto") { |_c| enviar }
        @dlg.add_action_callback("recontar") { |_c| abrir }
        @dlg.add_action_callback("salvar_csv") { |_c| salvar_csv }
        @dlg.show
      end

      def self.enviar
        @dlg.execute_script("carregar(#{JSON.generate(@ultimo)})") if @dlg && @ultimo
      end

      def self.csv(itens)
        linhas = ["Grupo;Peca;Medida;Quantidade"]
        itens.each { |i| linhas << [i[:grupo], i[:peca], i[:medida], i[:qtd]].join(";") }
        "﻿" + linhas.join("\r\n") + "\r\n"
      end

      def self.salvar_csv
        return unless @ultimo

        model = Sketchup.active_model
        dir = model.path.to_s.empty? ? nil : File.dirname(model.path)
        nome = "#{@ultimo[:modelo].empty? ? 'Modelo' : @ultimo[:modelo]} - pecas octanorm.csv"
        caminho = UI.savepanel("Salvar lista de pecas", dir, nome)
        return unless caminho

        caminho += ".csv" unless caminho.downcase.end_with?(".csv")
        File.write(caminho, csv(@ultimo[:itens]), encoding: "UTF-8")
        UI.messagebox("Lista salva:\n#{caminho}")
      rescue StandardError => e
        UI.messagebox("Nao foi possivel salvar:\n#{e.message}")
      end
    end
  end
end
