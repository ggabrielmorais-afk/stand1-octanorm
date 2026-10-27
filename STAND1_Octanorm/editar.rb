# encoding: UTF-8
# =============================================================================
# STAND1 Octanorm — editar.rb
# Editar depois de pronto: seleciona a parede, sala, ilha ou teto feito pelo
# plugin e troca medida, testeira, fechamento ou porta. O grupo e refeito no
# mesmo lugar a partir dos atributos gravados nele (mesmo esquema do Mover
# porta), entao continua onde foi movido.
#   parede aberta .... medida de cada trecho (mesmo ponto inicial e direcoes)
#   sala retangular .. L x P (mesmo 1o canto)
#   sala de outro formato: so as opcoes (a medida fica como esta)
#   teto ............. L x P e altura do topo
# =============================================================================
require 'json'

module STAND1
  module Octanorm
    module Editar
      ATRIB = Geometria::ATRIB
      PORTAS = { "Nenhuma" => :nenhuma, "Octanorm" => :octanorm, "Vidro" => :vidro }.freeze
      TESTEIRA = { "Sim (2,90)" => true, "Nao (2,20)" => false }.freeze

      def self.do_plugin?(e)
        e.is_a?(Sketchup::Group) && (e.get_attribute(ATRIB, "pontos") || e.get_attribute(ATRIB, "tipo") == "teto") ? true : false
      end

      # grupo do plugin selecionado, ou o que esta aberto pra edicao (clicou dentro dele)
      def self.grupo(model)
        model.selection.find { |e| do_plugin?(e) } || (model.active_path || []).reverse.find { |e| do_plugin?(e) }
      end

      # estava dentro do grupo: sai dele antes de refazer
      def self.sair_de(model, g)
        10.times do
          break unless (model.active_path || []).include?(g)

          model.close_active
        end
      end

      def self.executar
        model = Sketchup.active_model
        g = grupo(model)
        unless g
          UI.messagebox("Selecione uma parede, sala, ilha ou teto feito pelo STAND1 Octanorm e clique em Editar.")
          return
        end
        sair_de(model, g)
        g.get_attribute(ATRIB, "tipo") == "teto" ? perguntar_teto(model, g) : perguntar_parede(model, g)
      end

      # Texto do campo de medida: cada trecho (parede aberta) ou L x P (sala
      # retangular). nil = sala de outro formato, sem campo de medida.
      def self.medida_atual(pontos, fechado)
        trechos = Layout.trechos(pontos, fechado)
        return trechos.map { |t| Layout.metros(t[:comprimento]) }.join("; ") unless fechado
        return nil unless Layout.retangulo?(pontos)

        "#{Layout.metros(trechos[0][:comprimento])} x #{Layout.metros(trechos[1][:comprimento])}"
      end

      def self.perguntar_parede(model, g)
        a = ->(k) { g.get_attribute(ATRIB, k) }
        fechado = a.call("fechado") ? true : false
        ilha = a.call("so_testeira") ? true : false
        fechamento = a.call("fechamento").to_s.to_sym
        medida = medida_atual(JSON.parse(a.call("pontos")), fechado)

        campos = [] # [rotulo, valor atual, opcoes]
        rotulo = if !fechado then "Medida dos trechos (m, separe com ;)"
                 elsif ilha then "Medida da ilha (L x P, m)"
                 else "Medida da sala (L x P, m)"
                 end
        campos << [rotulo, medida, ""] if medida
        if ilha
          campos << ["Testeira (ilha) em", ILHA_OPCOES.key(fechamento) || ILHA_OPCOES.keys.first, ILHA_OPCOES.keys.join("|")]
        else
          campos << ["Testeira 0,70 em cima", TESTEIRA.key(a.call("testeira") ? true : false), TESTEIRA.keys.join("|")]
          campos << ["Fechamento", FECHAMENTO_OPCOES.key(fechamento) || FECHAMENTO_OPCOES.keys.first,
                     FECHAMENTO_OPCOES.keys.join("|")]
          campos << ["Porta", PORTAS.key(a.call("porta").to_s.to_sym) || "Nenhuma", PORTAS.keys.join("|")]
          if fechado
            amb = a.call("ambiente").to_s
            tipo = Layout::AMBIENTES.key(amb.split(" ").first) || "Sala"
            campos << ["Tipo de ambiente", tipo, Layout::AMBIENTES.keys.join("|")]
            campos << ["Complemento (opcional)", amb.split(" ", 2)[1].to_s, ""]
          end
        end
        titulo = ilha ? "STAND1 Octanorm: editar testeira de ilha" : "STAND1 Octanorm: editar parede"
        r = UI.inputbox(campos.map { |c| c[0] }, campos.map { |c| c[1] }, campos.map { |c| c[2] }, titulo)
        return unless r

        r = r.dup
        texto = medida ? r.shift.to_s.strip : nil
        mudancas = { medida: (texto && texto != medida ? texto : nil) } # medida igual: nao mexe nos pontos
        if ilha
          mudancas[:fechamento] = ILHA_OPCOES[r[0]]
        else
          mudancas.merge!(testeira: TESTEIRA[r[0]], fechamento: FECHAMENTO_OPCOES[r[1]], porta: PORTAS[r[2]])
          mudancas[:ambiente] = Layout.nome_ambiente(r[3], r[4]) if fechado
        end

        model.start_operation("STAND1 Octanorm: editar", true)
        begin
          trechos = aplicar_parede(model, g, **mudancas)
          model.commit_operation
        rescue StandardError => e
          model.abort_operation
          UI.messagebox("Nao deu pra editar:\n#{e.message}")
          return
        end
        Octanorm.relatorio(trechos, opcoes_do_grupo(g))
      end

      # Refaz a parede ou ilha com as mudancas (nil = mantem como esta).
      #   medida: texto do campo ("3; 2,5" na parede aberta, "4 x 3" na sala)
      # Devolve os trechos novos (pro relatorio). ArgumentError se a medida nao serve.
      def self.aplicar_parede(model, g, medida: nil, testeira: nil, fechamento: nil, porta: nil, ambiente: nil)
        a = ->(k) { g.get_attribute(ATRIB, k) }
        pontos = JSON.parse(a.call("pontos"))
        fechado = a.call("fechado") ? true : false
        ilha = a.call("so_testeira") ? true : false
        compartilhados = a.call("compartilhados") ? JSON.parse(a.call("compartilhados")) : []

        novos = pontos
        if medida && fechado
          raise ArgumentError, "so sala retangular muda de medida aqui" unless Layout.retangulo?(pontos)

          dims = Layout.ler_dimensoes(medida)
          raise ArgumentError, "medida da sala nao entendida: #{medida} (use L x P, ex.: 4 x 3)" unless dims

          novos = Layout.refazer_retangulo(pontos, dims[0], dims[1])
        elsif medida
          lista = Layout.ler_lista(medida)
          raise ArgumentError, "medida nao entendida: #{medida} (ex.: 3; 2,5)" unless lista

          novos = Layout.refazer_pontos(pontos, lista)
        end
        # montante de outra parede so continua compartilhado se o ponto nao saiu do lugar
        compartilhados = compartilhados.select { |c| novos.any? { |q| Layout.dist(c, q) < 1.0 } }
        trechos = Layout.trechos(novos, fechado, compartilhados)

        porta = ilha ? :nenhuma : (porta || a.call("porta").to_s.to_sym)
        porta_pos = nil
        if porta != :nenhuma && a.call("porta_pos")
          atual = JSON.parse(a.call("porta_pos"), symbolize_names: true)
          t = trechos[atual[:trecho]]
          f = t && Layout.folhas(t[:comprimento])[:folhas][atual[:vao]]
          porta_pos = atual if f && Layout.inteiro?(f) # o vao ainda existe: a porta fica onde estava
        end
        testeira = a.call("testeira") ? true : false if testeira.nil?

        Geometria.construir(model, pontos: novos, fechado: fechado, altura: a.call("altura").to_f,
                                   fechamento: fechamento || a.call("fechamento").to_s.to_sym,
                                   testeira: ilha || testeira, porta: porta, porta_pos: porta_pos, grupo: g,
                                   compartilhados: compartilhados, so_testeira: ilha, ambiente: ambiente)
        trechos
      end

      def self.opcoes_do_grupo(g)
        a = ->(k) { g.get_attribute(ATRIB, k) }
        { altura: a.call("altura").to_f, testeira: a.call("testeira") ? true : false,
          porta: a.call("porta").to_s.to_sym, so_testeira: a.call("so_testeira") ? true : false,
          porta_pos: a.call("porta_pos") ? JSON.parse(a.call("porta_pos"), symbolize_names: true) : nil }
      end

      def self.perguntar_teto(model, g)
        a = ->(k) { g.get_attribute(ATRIB, k) }
        medida = "#{Layout.metros(a.call('l'))} x #{Layout.metros(a.call('p'))}"
        alt = Teto::ALTURAS.key(a.call("altura").to_f) || Teto::ALTURAS.keys.first
        forro = Teto::FORROS.key(a.call("forro")) || Teto::FORROS.keys.first
        r = UI.inputbox(["Medida (L x P, m)", "Topo do teto", "Fechar o teto com"], [medida, alt, forro],
                        ["", Teto::ALTURAS.keys.join("|"), Teto::FORROS.keys.join("|")], "STAND1 Octanorm: editar teto")
        return unless r

        model.start_operation("STAND1 Octanorm: editar teto", true)
        begin
          aplicar_teto(model, g, medida: (r[0].to_s.strip == medida ? nil : r[0]), altura: Teto::ALTURAS[r[1]],
                                 forro: Teto::FORROS[r[2]] || "")
          model.commit_operation
        rescue StandardError => e
          model.abort_operation
          UI.messagebox("Nao deu pra editar o teto:\n#{e.message}")
          return
        end
        Teto.relatorio(g)
      end

      # Refaz o teto no mesmo canto e no mesmo angulo. Os lados em cima de
      # parede e os montantes ate o chao sao recalculados com o que esta no modelo agora.
      # forro: nil = mantem; "" = tira; "eucatex" = poe
      def self.aplicar_teto(model, g, medida: nil, altura: nil, forro: nil)
        a = ->(k) { g.get_attribute(ATRIB, k) }
        l = a.call("l").to_f
        p = a.call("p").to_f
        if medida
          dims = Layout.ler_dimensoes(medida)
          raise ArgumentError, "medida nao entendida: #{medida} (use L x P, ex.: 4 x 3)" unless dims

          l, p = dims
        end
        Teto.construir(model, origem: JSON.parse(a.call("origem")), angulo: a.call("angulo").to_f, l: l, p: p,
                              altura: altura || a.call("altura").to_f, grupo: g,
                              forro: (forro.nil? ? a.call("forro") : (forro.empty? ? nil : forro)))
      end
    end
  end
end
