# encoding: UTF-8
# =============================================================================
# STAND1 Octanorm — mobiliario.rb
#
# Balcao: clica o caminho no piso e ele divide em modulos de 1,00/0,50 m,
# medidos de eixo a eixo de montante, igual parede. Montante compartilhado na
# emenda; cada modulo conta como UM balcao no Memorial.
#   TS ........ folha dentro do perfil
#   Vidro/MDF . placa na frente do perfil, presa por spider, sem Z500
#   Expositor . folha embaixo, travessa e prateleira no corte, vitrine de vidro
#               nos 4 lados e no topo (medidas do bloco Balcao especial (3))
#   Fundo ..... sempre TS (no expositor, so abaixo da vitrine)
#
# Encostado em parede Octanorm, usa os montantes dela em vez de por outros:
#   De costas . clica os montantes da parede, olhando de onde o balcao vai
#               ficar, da esquerda pra direita: a linha clicada vira o fundo.
#   De ponta .. comeca ou termina num montante da parede: no vidro e no MDF, o
#               lado que fica na linha da parede sai sem placa e sem spider.
# A folha e as travessas do balcao ficam encostadas na parede, sem atravessar.
#
# Prateleira: caixa digitada, com postes nos 4 cantos e travessas em niveis.
# =============================================================================

module STAND1
  module Octanorm
    module Mobiliario
      TAG = "MOBILIÁRIO".freeze

      FECHAMENTO_OPCOES = { "TS branco" => :ts, "Vidro" => :vidro, "MDF" => :mdf,
                            "Expositor (vitrine de vidro em cima)" => :expositor }.freeze
      ROTULO_FECHAMENTO = { ts: "TS", vidro: "Vidro", mdf: "MDF", expositor: "Expositor" }.freeze

      ALTURA_MINIMA = 30.0
      ALTURA_MINIMA_EXPOSITOR = 60.0
      VITRINE_TOPO = 30.0 # do topo da travessa do corte ate o topo do balcao
      FOLGA_PLACA = (100.0 - Geometria::VIDRO_LARGURA) / 2.0
      PLACA_ABAIXO_TOPO = 1.28
      VIDRO_ABAIXO_TOPO = 0.63
      ENCAIXE_X = 0.7 # a placa deitada entra no canal do perfil
      ENCAIXE_Y = 0.75
      ESPESSURA_DEITADA = 0.44
      AFASTA_PAREDE_VIDRO = 6.0 # passa do vidro e do spider que a parede tem na frente
      SPIDER_FORA_DA_PAREDE = 2.23 # meio miolo do spider + meia folha da parede

      def self.placa_horizontal(ents, x0, x1, y0, y1, z, mat, espessura = ESPESSURA_DEITADA)
        base = z - espessura / 2.0
        g = ents.add_group
        pts = [[x0, y0], [x1, y0], [x1, y1], [x0, y1]].map { |x, y| Geom::Point3d.new(x.cm, y.cm, base.cm) }
        f = g.entities.add_face(pts)
        f.reverse! if f.normal.z < 0
        f.pushpull(espessura.cm)
        g.material = mat
      end

      def self.com_spider?(fechamento)
        %i[vidro mdf].include?(fechamento)
      end

      def self.corte(altura)
        altura - VITRINE_TOPO
      end

      def self.niveis_travessa(fechamento, altura, ht)
        return [0.0, corte(altura) - ht, altura - ht] if fechamento == :expositor

        [0.0, altura - ht]
      end

      # Face desenhada no proprio sistema: largura em X, lado de fora em -Y.
      def self.fechar_face(ents, mats, tipo, largura, altura, ht, margem)
        xa = margem
        xb = largura - margem
        case tipo
        when :ts
          Geometria.placa(ents, xa, xb, ht, altura - ht, mats[:ts])
        when :vidro, :mdf
          Geometria.placa(ents, FOLGA_PLACA, largura - FOLGA_PLACA, 0.0, altura, mats[tipo],
                          Geometria::VIDRO_Y, Geometria::VIDRO_ESPESSURA)
        when :expositor
          Geometria.placa(ents, xa, xb, ht, corte(altura) - ht, mats[:ts])
          Geometria.placa(ents, xa, xb, corte(altura) - 0.15, altura - ht + 0.22, mats[:vidro])
        end
      end

      def self.spiders(ents, spider, nos, altura)
        nos.each do |x, lados|
          Geometria.colocar_bracos(ents, spider, x, Geometria::SPIDER_PE, lados, [:sobe])
          Geometria.colocar_bracos(ents, spider, x, altura - Geometria::SPIDER_PE, lados, [:desce])
        end
      end

      # No canto, o 1o no da frente tambem segura a lateral do trecho anterior:
      # as duas placas ficam no mesmo plano e dividem um spider de 2 garras.
      def self.nos_da_frente(eixos, canto)
        ultimo = eixos.size - 1
        eixos.each_with_index.map do |x, k|
          lados = []
          lados << :esq if k > 0 || canto
          lados << :dir if k < ultimo
          [x, lados]
        end
      end

      # No montante da parede o miolo do spider passaria pela folha dela: anda
      # pro lado da placa. tem_parede: se aquele no e montante da parede.
      def self.fora_da_parede(x, lados, tem_parede)
        return x unless tem_parede && lados.size == 1

        lados == [:dir] ? x + SPIDER_FORA_DA_PAREDE : x - SPIDER_FORA_DA_PAREDE
      end

      def self.face(ents, tr, nome, largura, pecas, mats, tipo, niveis, altura, ht, margem)
        g = ents.add_group
        g.name = nome
        niveis.each do |z0|
          Geometria.encaixar(g.entities, pecas[:travessa], longo: :x, x0: margem, x1: largura - margem, z0: z0)
        end
        fechar_face(g.entities, mats, tipo, largura, altura, ht, margem) if tipo
        g.transformation = tr
        g
      end

      # So pontos-guia: a caixa mede o modulo exato e o nome se repete sem "#1".
      def self.marcador(model, nome, comprimento, profundidade, altura)
        chave = ["v1", "balcao", nome].join("|")
        d = model.definitions.find { |x| x.get_attribute(Geometria::ATRIB, "chave") == chave }
        return d if d

        d = model.definitions.add(nome)
        d.set_attribute(Geometria::ATRIB, "chave", chave)
        d.entities.add_cpoint(Geom::Point3d.new(0, 0, 0))
        d.entities.add_cpoint(Geom::Point3d.new(comprimento.cm, profundidade.cm, altura.cm))
        d
      end

      def self.mover(x, y)
        Geom::Transformation.translation(Geom::Vector3d.new(x.cm, y.cm, 0))
      end

      def self.girar(graus)
        Geom::Transformation.rotation(ORIGIN, Z_AXIS, graus.degrees)
      end

      def self.montar_modulos(model, grupo, g, tr, folhas, pecas, mats, fechamento, profundidade, altura, ht, margem, tag, enc)
        niveis = niveis_travessa(fechamento, altura, ht)
        fundo = fechamento == :expositor ? :expositor : :ts
        nome = "Balcão #{ROTULO_FECHAMENTO[fechamento]} "
        y_fundo = profundidade - enc[:afasta_fundo]
        folhas.each_with_index do |f, n|
          x = f[:x]
          l = f[:largura]
          face(g.entities, mover(x, 0), "Frente", l, pecas, mats, fechamento, niveis, altura, ht, margem)
          face(g.entities, mover(x + l, y_fundo) * girar(180), "Fundo", l, pecas, mats, fundo, niveis, altura, ht, margem)

          xa = x + ENCAIXE_X
          xb = x + l - ENCAIXE_X
          xa += enc[:recuo_inicio] if n.zero?
          xb -= enc[:recuo_fim] if n == folhas.size - 1
          ya = ENCAIXE_Y
          yb = y_fundo - ENCAIXE_Y
          placa_horizontal(g.entities, xa, xb, ya, yb, ht - PLACA_ABAIXO_TOPO, mats[:ts])
          if fechamento == :expositor
            placa_horizontal(g.entities, xa, xb, ya, yb, corte(altura) - PLACA_ABAIXO_TOPO, mats[:ts])
            placa_horizontal(g.entities, xa, xb, ya, yb, altura - VIDRO_ABAIXO_TOPO, mats[:vidro])
          else
            placa_horizontal(g.entities, xa, xb, ya, yb, altura - PLACA_ABAIXO_TOPO, mats[:ts])
          end

          rotulo = "#{nome}#{Layout.metros(l)} x #{Layout.metros(profundidade)} x #{Layout.metros(altura)} m"
          marc = marcador(model, rotulo, l, profundidade, altura)
          grupo.entities.add_instance(marc, tr * mover(x, 0)).layer = tag
        end
      end

      def self.montar_divisoes(g, eixos, canto, segue_canto, t, pecas, mats, fechamento, profundidade, altura, ht, margem, enc)
        niveis = niveis_travessa(fechamento, altura, ht)
        ultimo = eixos.size - 1
        eixos.each_with_index do |x, k|
          recuo = if k.zero? then enc[:recuo_inicio]
                  elsif k == ultimo then -enc[:recuo_fim]
                  else 0.0
                  end
          na_parede = recuo != 0.0
          xr = x + recuo
          sem_frente = (k.zero? && !t[:montante_inicio]) || (k == ultimo && !t[:montante_fim]) || enc[:tem_montante].call(x, 0.0)
          Geometria.encaixar(g.entities, pecas[:montante], longo: :z, x0: x, y_centro: 0.0, z0: 0.0, z1: altura) unless sem_frente
          unless enc[:tem_montante].call(x, profundidade)
            Geometria.encaixar(g.entities, pecas[:montante], longo: :z, x0: xr, y_centro: profundidade, z0: 0.0, z1: altura)
          end
          next if k.zero? && canto # encosta no fundo do trecho anterior

          ponta = k.zero? || k == ultimo
          tipo = ponta ? fechamento : nil
          tipo = nil if na_parede && com_spider?(fechamento) # a parede fecha esse lado
          tr = k.zero? ? mover(xr, profundidade) * girar(-90) : mover(xr, 0) * girar(90)
          lado = face(g.entities, tr, ponta ? "Lateral" : "Divisao", profundidade, pecas, mats, tipo, niveis, altura, ht, margem)
          next unless ponta && com_spider?(fechamento) && !na_parede

          nos = [[0.0, [:dir]]]
          nos << [profundidade, [:esq]] unless k == ultimo && segue_canto
          nos = nos.map do |lx, lados|
            y = k.zero? ? profundidade - lx : lx # X da lateral -> Y do trecho
            [fora_da_parede(lx, lados, enc[:tem_montante].call(x, y)), lados]
          end
          spiders(lado.entities, pecas[:spider], nos, altura)
        end
      end

      # Devolve [grupo, avisos]. No canto o trecho seguinte comeca depois da
      # profundidade do anterior, senao as caixas ocupariam o mesmo lugar.
      # paredes: ver Layout.parede_sob.
      def self.construir_balcao(model, pontos:, fechado:, fechamento:, profundidade:, altura:, compartilhados: [], paredes: [])
        costas = pontos.size == 2 && !fechado ? Layout.parede_sob(pontos[0], pontos[1], paredes) : nil
        folhas_da_parede = nil
        if costas
          folhas_da_parede = Layout.folhas_na_parede(pontos[0], pontos[1], costas[:eixos])
          pontos = Layout.a_direita(pontos, profundidade)
          compartilhados = []
        end
        montantes = paredes.flat_map { |p| p[:eixos] }
        trechos = Layout.trechos(pontos, fechado, compartilhados)
        mats = Geometria.materiais(model)
        pecas = { montante: Geometria.peca(model, :montante), travessa: Geometria.peca(model, :travessa) }
        pecas[:spider] = Geometria.peca(model, :spider) if com_spider?(fechamento)
        margem = Geometria.largura_montante(pecas[:montante]) / 2.0
        ht = Geometria.altura_travessa(pecas[:travessa])
        afastamento = ->(parede) { parede[:vidro] ? AFASTA_PAREDE_VIDRO : margem * 2.0 }
        tag = model.layers[TAG] || model.layers.add(TAG)
        espelho = Layout.horario?(pontos) ? Geom::Transformation.scaling(ORIGIN, 1, -1, 1) : Geom::Transformation.new
        fechado_de_verdade = fechado && trechos.size >= 3
        avisos = []

        grupo = model.active_entities.add_group
        grupo.name = "Balcão #{ROTULO_FECHAMENTO[fechamento]}"

        trechos.each_with_index do |t, i|
          canto = i > 0 || fechado_de_verdade
          inicio = canto ? profundidade : 0.0
          util = t[:comprimento] - inicio
          r = if folhas_da_parede then { folhas: folhas_da_parede }
              elsif util > 0 then Layout.folhas(util, inicio: t[:sobra_no_inicio] ? true : false)
              else { folhas: [] }
              end
          avisos << "trecho #{i + 1}: #{r[:aviso]}" if r[:aviso]
          if canto && r[:folhas].any? { |f| f[:meio] }
            inteiro = (util / Layout::MODULO).ceil * Layout::MODULO + inicio
            avisos << "trecho #{i + 1}: o canto gerou módulo de 0,50. Com #{Layout.metros(inteiro)} m ficam só módulos de 1,00."
          end
          if r[:folhas].empty?
            avisos << "trecho #{i + 1}: curto demais, nao coube nenhum modulo depois do canto"
            next
          end

          folhas = r[:folhas].map { |f| f.merge(x: f[:x] + inicio) }
          eixos = [folhas.first[:x]] + folhas.map { |f| f[:x] + f[:largura] }
          origem = Geom::Point3d.new(t[:inicio][0].cm, t[:inicio][1].cm, 0)
          tr = Geom::Transformation.translation(origem) * Geom::Transformation.rotation(ORIGIN, Z_AXIS, t[:angulo]) * espelho

          g = grupo.entities.add_group
          g.name = "Trecho"
          segue_canto = i < trechos.size - 1 || fechado_de_verdade

          no_mundo = lambda do |x, y|
            p = Geom::Point3d.new(x.cm, y.cm, 0).transform(tr)
            [p.x.to_cm, p.y.to_cm]
          end
          recuo_da_ponta = lambda do |x|
            parede = Layout.parede_sob(no_mundo.call(x, 0.0), no_mundo.call(x, profundidade), paredes)
            parede ? afastamento.call(parede) : 0.0
          end
          enc = {
            tem_montante: ->(x, y) { p = no_mundo.call(x, y); montantes.any? { |m| Layout.dist(m, p) < Layout::TOLERANCIA_PAREDE } },
            afasta_fundo: costas ? afastamento.call(costas) : 0.0,
            recuo_inicio: canto ? 0.0 : recuo_da_ponta.call(eixos.first),
            recuo_fim: segue_canto ? 0.0 : recuo_da_ponta.call(eixos.last)
          }
          montar_divisoes(g, eixos, canto, segue_canto, t, pecas, mats, fechamento, profundidade, altura, ht, margem, enc)
          montar_modulos(model, grupo, g, tr, folhas, pecas, mats, fechamento, profundidade, altura, ht, margem, tag, enc)
          if com_spider?(fechamento)
            nos = nos_da_frente(eixos, canto).map { |x, lados| [fora_da_parede(x, lados, enc[:tem_montante].call(x, 0.0)), lados] }
            spiders(g.entities, pecas[:spider], nos, altura)
          end
          g.transformation = tr
        end
        [grupo, avisos]
      end

      # Mesma interacao de clique da parede; so muda o que monta ao terminar.
      class FerramentaBalcao < Ferramenta
        def initialize(fechamento, profundidade, altura)
          @fechamento = fechamento
          @profundidade = profundidade
          @altura = altura
          super({ fechamento: fechamento })
        end

        # Testeira de ilha fica no alto, sem montante ate o chao no meio do vao.
        def parede_serve?(grupo)
          !grupo.get_attribute(Geometria::ATRIB, "so_testeira")
        end

        def carregar_imas
          @paredes = []
          super
        end

        def registrar_trilho(montantes, grupo)
          super
          @paredes << { eixos: montantes.map { |p| [p.x.to_cm, p.y.to_cm] },
                        vidro: grupo.get_attribute(Geometria::ATRIB, "fechamento") == "vidro" }
        end

        def status
          Sketchup.status_text = if @pts.empty?
                                   "STAND1 Octanorm: clique o ponto inicial da FRENTE do balcão. " \
                                   "De costas pra parede: clique os montantes dela da esquerda pra direita."
                                 else
                                   "Clique o próximo ponto (módulos de 1,00/0,50 m). F fecha. " \
                                   "Backspace desfaz. Duplo clique ou Enter termina."
                                 end
          Sketchup.vcb_label = "Comprimento"
        end

        def terminar(view, fechado)
          pts = @pts.dup
          if pts.size < 2
            resetar
            return
          end
          cm = pts.map { |p| [p.x.to_cm, p.y.to_cm] }
          if (cm.size > 2 || fechado) && Layout.algum_trecho_em_parede?(cm, fechado, @paredes)
            UI.messagebox("De costas pra parede, desenhe um trecho reto de cada vez.")
            resetar
            return
          end
          model = Sketchup.active_model
          model.start_operation("STAND1 Octanorm: balcão", true)
          begin
            grupo, avisos = Mobiliario.construir_balcao(model, pontos: cm, fechado: fechado, fechamento: @fechamento,
                                                        profundidade: @profundidade, altura: @altura,
                                                        compartilhados: @compartilhados, paredes: @paredes)
            model.commit_operation
          rescue StandardError => e
            model.abort_operation
            UI.messagebox("Erro ao montar o balcão:\n#{e.message}")
            resetar
            return
          end
          model.selection.clear
          model.selection.add(grupo)
          UI.messagebox("Atenção:\n- #{avisos.join("\n- ")}") if avisos.any?
          resetar
          view.invalidate
        end
      end

      # ---- Prateleira ---------------------------------------------------------

      ALTURA_PRATELEIRA = 220.0
      MODULO_PRATELEIRA = 55.0

      def self.postes(ents, montante, comprimento, profundidade, altura, z0 = 0.0)
        [[0.0, 0.0], [comprimento, 0.0], [0.0, profundidade], [comprimento, profundidade]].each do |x, y|
          Geometria.encaixar(ents, montante, longo: :z, x0: x, y_centro: y, z0: z0, z1: altura)
        end
      end

      def self.quadro(ents, travessa, comprimento, profundidade, nivel, margem)
        ht = Geometria.altura_travessa(travessa)
        z0 = nivel <= 0.01 ? 0.0 : nivel - ht
        Geometria.encaixar(ents, travessa, longo: :x, x0: margem, x1: comprimento - margem, y_centro: 0.0, z0: z0)
        Geometria.encaixar(ents, travessa, longo: :x, x0: margem, x1: comprimento - margem, y_centro: profundidade, z0: z0)
        Geometria.encaixar(ents, travessa, longo: :y, x0: 0.0, y0: margem, y1: profundidade - margem, z0: z0)
        Geometria.encaixar(ents, travessa, longo: :y, x0: comprimento, y0: margem, y1: profundidade - margem, z0: z0)
      end

      def self.niveis_prateleira(altura, modulo)
        n = (altura / modulo).floor
        (0..n).map { |i| [i * modulo, altura].min }.uniq
      end

      def self.construir_prateleira(model, comprimento:, profundidade:, altura: ALTURA_PRATELEIRA, modulo: MODULO_PRATELEIRA)
        mats = Geometria.materiais(model)
        pecas = { montante: Geometria.peca(model, :montante), travessa: Geometria.peca(model, :travessa) }
        margem = Geometria.largura_montante(pecas[:montante]) / 2.0

        nome = "Prateleira de alumínio #{Layout.metros(comprimento)} x #{Layout.metros(profundidade)} x " \
               "#{Layout.metros(altura)} m"
        chave = ["v2", "prateleira", comprimento, profundidade, altura].join("|")
        defn = model.definitions.find { |d| d.get_attribute(Geometria::ATRIB, "chave") == chave }
        unless defn
          defn = model.definitions.add(nome)
          defn.set_attribute(Geometria::ATRIB, "chave", chave)
          ents = defn.entities
          postes(ents, pecas[:montante], comprimento, profundidade, altura)
          niveis_prateleira(altura, modulo).each do |z|
            quadro(ents, pecas[:travessa], comprimento, profundidade, z, margem)
            next if z <= 0.01 # no chao so a travessa de apoio

            placa_horizontal(ents, margem, comprimento - margem, margem, profundidade - margem, z, mats[:ts],
                             Geometria::PAINEL_ESPESSURA)
          end
          Geometria.sem_tag_de_secao(defn)
        end

        inst = model.active_entities.add_instance(defn, Geom::Transformation.new)
        inst.layer = model.layers[TAG] || model.layers.add(TAG)
        inst.name = nome
        inst
      end
    end
  end
end
