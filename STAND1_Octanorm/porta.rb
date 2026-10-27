# encoding: UTF-8
# =============================================================================
# STAND1 Octanorm — porta.rb
# Ferramenta "Mover porta": clica num vao de qualquer parede feita pelo plugin
# e a porta vai pra la (a parede e refeita a partir dos atributos gravados).
# Clicar no vao onde a porta ja esta tira a porta.
# =============================================================================
require 'json'

module STAND1
  module Octanorm
    class FerramentaPorta
      ATRIB = Geometria::ATRIB

      def activate
        @ip = Sketchup::InputPoint.new
        Sketchup.status_text = "Mover porta: clique no vao da parede Octanorm onde a porta deve ficar. " \
                               "Clique no vao da porta atual pra tirar a porta. Esc sai."
      end

      def onMouseMove(_flags, x, y, view)
        @ip.pick(view, x, y)
        view.invalidate
      end

      def draw(view)
        @ip.draw(view) if @ip && @ip.valid?
      end

      def onCancel(_reason, _view)
        Sketchup.active_model.select_tool(nil)
      end

      # grupo de parede Octanorm sob o cursor + transformacao acumulada ate ele
      def parede_sob_cursor(view, x, y)
        ph = view.pick_helper
        ph.do_pick(x, y)
        ph.count.times do |i|
          caminho = ph.path_at(i) || []
          idx = caminho.index { |e| e.is_a?(Sketchup::Group) && e.get_attribute(ATRIB, "pontos") }
          next unless idx

          tr = caminho[0..idx].map(&:transformation).inject(Geom::Transformation.new) { |a, b| a * b }
          # o caminho do pick_helper e relativo ao contexto ativo
          tr = Sketchup.active_model.edit_transform * tr
          return [caminho[idx], tr]
        end
        nil
      end

      def onLButtonDown(_flags, x, y, view)
        @ip.pick(view, x, y)
        grupo, tr = parede_sob_cursor(view, x, y)
        unless grupo
          UI.beep
          Sketchup.status_text = "Clique em cima de uma parede feita pelo STAND1 Octanorm."
          return
        end
        local = @ip.position.transform(tr.inverse)
        Octanorm.mover_porta(grupo, local.x.to_cm, local.y.to_cm)
        view.invalidate
      end
    end

    # Le os atributos da parede, troca a posicao da porta e refaz.
    def self.mover_porta(grupo, x_cm, y_cm)
      a = ->(k) { grupo.get_attribute(Geometria::ATRIB, k) }
      if a.call("so_testeira")
        UI.beep
        Sketchup.status_text = "Testeira de ilha nao tem porta."
        return
      end
      pontos = JSON.parse(a.call("pontos"))
      fechado = a.call("fechado") ? true : false
      compartilhados = a.call("compartilhados") ? JSON.parse(a.call("compartilhados")) : []
      trechos = Layout.trechos(pontos, fechado, compartilhados)
      novo = Layout.vao_no_ponto(trechos, x_cm, y_cm)
      unless novo
        UI.beep
        Sketchup.status_text = "Esse vao nao e de 1,00 m (meio modulo ou folha especial). Porta so entra em vao inteiro."
        return
      end
      atual = a.call("porta_pos") ? JSON.parse(a.call("porta_pos"), symbolize_names: true) : nil
      porta = a.call("porta").to_s
      if porta != "nenhuma" && atual == novo
        porta = "nenhuma" # clicou na porta que ja existe: tira
        novo = nil
      elsif porta == "nenhuma"
        porta = a.call("fechamento").to_s == "vidro" ? "vidro" : "octanorm"
      end

      model = Sketchup.active_model
      model.start_operation("STAND1 Octanorm: mover porta", true)
      begin
        Geometria.construir(model, pontos: pontos, fechado: fechado, altura: a.call("altura").to_f,
                                   fechamento: a.call("fechamento").to_sym, testeira: a.call("testeira") ? true : false,
                                   porta: porta.to_sym, porta_pos: novo, grupo: grupo,
                                   compartilhados: compartilhados)
        model.commit_operation
      rescue => e
        model.abort_operation
        UI.messagebox("Erro ao mover a porta:\n#{e.message}")
      end
    end
  end
end
