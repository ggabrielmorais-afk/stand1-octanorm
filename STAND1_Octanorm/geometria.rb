# encoding: UTF-8
# =============================================================================
# STAND1 Octanorm — geometria.rb
#
# Pecas em stand1_octanorm/pecas (copiadas de CATALOGO STAND1\PLuguin):
#   Octanorm.skp ......... montante (esticado na altura)
#   Travesa.skp .......... travessa (esticada no vao)
#   Z500.skp ............. perfil alto do topo da testeira de VIDRO
#   Spider.skp ........... spider inteiro (emenda de placas de vidro)
#   (spider montado por bracos: so do lado que tem vidro)
#   Porta Octanorm.skp ... porta TS
#   Porta de vidro.skp ... porta de vidro
#
# Linha da parede (Y = 0) = eixo dos montantes. Medidas lidas dos blocos da
# Stand1 em 26/10/2026 (montagem_blocos.json e montagem_vidro_v2.json).
#
# TS:    Travesa no pe, folha TS 0,46 cm no meio, Travesa no topo (2,20).
#        Testeira TS: folha + Travesa em cima (2,90).
# Vidro: placas de 99,6 cm NA FRENTE do montante (3 cm a frente do eixo),
#        1,07 + 1,10 (2,20) e + 0,70 na testeira de vidro (2,90). Bracos de spider
#        so do lado com vidro (pe, emendas, topo). Travesa no pe, Z500 no topo
#        da testeira de vidro, atras do vidro.
#
# Memorial: cada trecho reto vira UM componente na tag ESTRUTURAS com "Parede"
# no nome. Montantes e spiders ficam FORA dele; dois pontos-guia marcam 0 e o
# comprimento, pra caixa medir eixo a eixo (3,00 x 2,20 = 6,60 m2).
# =============================================================================

require 'json'

module STAND1
  module Octanorm
    module Geometria
      TAG = "ESTRUTURAS".freeze
      ATRIB = "stand1_octanorm".freeze
      TESTEIRA_ALTURA = 70.0
      PAINEL_ESPESSURA = 0.46 # folha TS
      PORTA_ALTURA = 220.0

      # vidro (cm, relativo a linha do montante)
      VIDRO_Y = -2.97          # centro da placa: 3 cm a frente do eixo
      VIDRO_ESPESSURA = 1.22
      VIDRO_LARGURA = 99.56
      VIDRO_FOLGA = 0.63       # entre placas empilhadas
      VIDRO_PAREDE = [[1.05, 107.8], [108.43, 218.19]].freeze # 1,07 + 1,10
      VIDRO_TESTEIRA = [0.0, 70.0].freeze                     # 0,70 (sobre a parede; Gabriel: 0,69 -> 0,70)
      SPIDER_Y_MIN = -3.87     # face da frente do spider

      PASTA_PECAS = File.join(File.dirname(__FILE__), "pecas")
      PECAS = { montante: "Octanorm.skp", travessa: "Travesa.skp", z500: "Z500.skp",
                spider: "Spider.skp",
                porta_octanorm: "Porta Octanorm.skp", porta_vidro: "Porta de vidro.skp" }.freeze
      NOMES_PORTA = { porta_octanorm: nil, porta_vidro: "Porta de vidro" }.freeze

      FECHAMENTOS = {
        ts:        { rotulo: "TS",        nome: "Parede octanorm TS",                   testeira: "Testeira octanorm" },
        vidro:     { rotulo: "Vidro",     nome: "Parede de vidro octanorm",             testeira: "Testeira de vidro octanorm" },
        estrutura: { rotulo: "Estrutura", nome: "Estrutura octanorm (sem fechamento)", testeira: "Testeira octanorm" },
        mdf:       { rotulo: "MDF",       nome: "Parede MDF",                           testeira: "Testeira MDF" }
      }.freeze

      def self.material(model, nome, rgb, alpha = 1.0)
        m = model.materials[nome] || model.materials.add(nome)
        m.color = Sketchup::Color.new(*rgb)
        m.alpha = alpha
        m
      end

      def self.materiais(model)
        {
          ts:    material(model, "Octanorm TS Branco", [246, 246, 244]),
          vidro: material(model, "Octanorm Vidro", [165, 185, 190], 0.30),
          mdf:   material(model, "Testeira MDF Branco", [250, 250, 248])
        }
      end

      # Carrega a peca uma vez por modelo (reaproveita se ja estiver la).
      def self.peca(model, chave)
        nome = NOMES_PORTA[chave] || "STAND1 peca #{chave}"
        d = model.definitions.find { |x| x.get_attribute(ATRIB, "peca") == chave.to_s }
        return d if d

        d = model.definitions.load(File.join(PASTA_PECAS, PECAS[chave]))
        d.name = nome
        d.set_attribute(ATRIB, "peca", chave.to_s)
        clarear_aluminio(d)
        sem_tag_de_secao(d)
        d
      end

      SECOES_MEMORIAL = ["ESTRUTURAS", "REVESTIMENTOS", "COMUNICAÇÃO VISUAL", "MOBILIÁRIO", "EQUIPAMENTOS", "ELÉTRICA"].freeze

      # Peca do plugin nunca conta sozinha no Memorial (ex.: a Porta Octanorm.skp
      # traz um componente interno na tag ESTRUTURAS). Quem conta e a parede/sala.
      def self.sem_tag_de_secao(defn, vistos = {})
        return if vistos[defn]

        vistos[defn] = true
        defn.entities.each do |e|
          next unless e.respond_to?(:definition)

          e.layer = defn.model.layers[0] if e.layer && SECOES_MEMORIAL.include?(e.layer.name.upcase) # Untagged
          sem_tag_de_secao(e.definition, vistos)
        end
      end

      ALUMINIO_BRILHO = 0.80 # HSB: B em 80 (o aluminio das pecas saia escuro demais)

      # Material de metal da peca (cinza, opaco, escuro) ganha B = 80 no HSB,
      # mantendo matiz e saturacao. Branco, vidro e cor forte ficam como estao.
      def self.clarear_aluminio(defn, vistos = {})
        return if vistos[defn]

        vistos[defn] = true
        defn.entities.each do |e|
          ajustar_brilho(e.material) if e.respond_to?(:material) && e.material
          clarear_aluminio(e.definition, vistos) if e.respond_to?(:definition)
        end
      end

      def self.ajustar_brilho(mat)
        return if mat.get_attribute(ATRIB, "brilho") || mat.alpha < 0.99

        c = mat.color
        r, g, b = [c.red, c.green, c.blue].map { |v| v / 255.0 }
        v = [r, g, b].max
        s = v.zero? ? 0.0 : (v - [r, g, b].min) / v
        return if s > 0.25 || v >= ALUMINIO_BRILHO # so metal cinza mais escuro que 80

        k = ALUMINIO_BRILHO / [v, 0.001].max
        mat.color = Sketchup::Color.new(*[r, g, b].map { |x| (x * k * 255).round.clamp(0, 255) })
        mat.set_attribute(ATRIB, "brilho", ALUMINIO_BRILHO)
      end

      def self.caixa_girada(defn, rot)
        b = defn.bounds
        bb = Geom::BoundingBox.new
        8.times { |i| bb.add(b.corner(i).transform(rot)) }
        bb
      end

      # Encaixa uma peca esticando so o eixo longo.
      #   longo: :x (travessa) -> ocupa x0..x1, centrada em y, base em z0
      #   longo: :z (montante) -> centrada em x0, centrada em y, ocupa z0..z1
      def self.encaixar(ents, defn, longo:, x0:, x1: nil, z0:, z1: nil)
        b = defn.bounds
        dims = { x: b.width, y: b.height, z: b.depth }
        maior = dims.max_by { |_k, v| v }[0]
        rot = Geom::Transformation.new
        if longo == :x && maior == :y
          rot = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees)
        elsif longo == :x && maior == :z
          rot = Geom::Transformation.rotation(ORIGIN, Y_AXIS, 90.degrees)
        elsif longo == :z && maior == :x
          rot = Geom::Transformation.rotation(ORIGIN, Y_AXIS, -90.degrees)
        elsif longo == :z && maior == :y
          rot = Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees)
        end
        bb = caixa_girada(defn, rot)
        if longo == :x
          ref = Geom::Point3d.new(bb.min.x, bb.center.y, bb.min.z)
          esc = Geom::Transformation.scaling(ORIGIN, (x1 - x0).cm / bb.width, 1, 1)
        else
          ref = Geom::Point3d.new(bb.center.x, bb.center.y, bb.min.z)
          esc = Geom::Transformation.scaling(ORIGIN, 1, 1, (z1 - z0).cm / bb.depth)
        end
        alvo = Geom::Point3d.new(x0.cm, 0, z0.cm)
        tr = Geom::Transformation.translation(alvo - ORIGIN) * esc *
             Geom::Transformation.translation(ORIGIN - ref) * rot
        ents.add_instance(defn, tr)
      end

      # Coloca uma peca sem esticar (spider, porta), alinhando a caixa dela:
      # centro em X, frente (y min) ou centro em Y, e base/centro/topo em Z.
      def self.alinhar(ents, defn, x_centro:, y_min: nil, y_centro: nil, z_min: nil, z_centro: nil, z_max: nil,
                       espelhar_z: false, tr: nil)
        b = defn.bounds
        esp = espelhar_z ? Geom::Transformation.scaling(ORIGIN, 1, 1, -1) : Geom::Transformation.new
        bb = caixa_girada(defn, esp)
        dz = if z_min then z_min.cm - bb.min.z
             elsif z_max then z_max.cm - bb.max.z
             else z_centro.cm - bb.center.z
             end
        dy = y_min ? y_min.cm - bb.min.y : y_centro.cm - bb.center.y
        mov = Geom::Transformation.translation(Geom::Vector3d.new(x_centro.cm - bb.center.x, dy, dz))
        inst = ents.add_instance(defn, (tr || Geom::Transformation.new) * mov * esp)
        inst
      end

      def self.largura_montante(defn)
        b = defn.bounds
        [b.width, b.height, b.depth].sort[0].to_cm
      end

      def self.altura_travessa(defn)
        b = defn.bounds
        [b.width, b.height, b.depth].sort[1].to_cm # 2a menor dimensao = altura do perfil
      end

      def self.placa(ents, x0, x1, z0, z1, mat, y_centro = 0.0, espessura = PAINEL_ESPESSURA)
        return if x1 - x0 <= 0.01 || z1 - z0 <= 0.01

        e = espessura / 2.0
        g = ents.add_group
        pts = [[x0, y_centro - e], [x1, y_centro - e], [x1, y_centro + e], [x0, y_centro + e]]
              .map { |x, y| Geom::Point3d.new(x.cm, y.cm, z0.cm) }
        f = g.entities.add_face(pts)
        f.reverse! if f.normal.z < 0
        f.pushpull((z1 - z0).cm)
        g.material = mat
      end

      # Componente de um trecho (parede ou testeira). vao_porta: indice do vao com
      # porta (nil = sem porta).
      def self.definicao(model, nome, chave, comprimento, altura, fechamento, tipo, mats, pecas, vao_porta = nil)
        existente = model.definitions.find { |d| d.get_attribute(ATRIB, "chave") == chave }
        return existente if existente

        d = model.definitions.add(nome)
        d.set_attribute(ATRIB, "chave", chave)
        d.set_attribute(ATRIB, "comprimento_cm", comprimento)
        d.set_attribute(ATRIB, "altura_cm", altura)
        ents = d.entities
        p = largura_montante(pecas[:montante]) / 2.0
        ht = altura_travessa(pecas[:travessa])

        Layout.folhas(comprimento)[:folhas].each_with_index do |f, i|
          xa = f[:x] + p
          xb = f[:x] + f[:largura] - p
          if tipo == :ilha
            vao_ilha(ents, f, xa, xb, altura, fechamento, mats, pecas, ht)
          elsif fechamento == :vidro
            vao_vidro(ents, f, xa, xb, altura, tipo, i == vao_porta, mats, pecas, ht)
          else
            vao_ts(ents, xa, xb, altura, tipo, fechamento, i == vao_porta, mats, pecas, ht)
          end
        end
        # pontos-guia: a caixa do componente fica exatamente 0..comprimento x 0..altura
        ents.add_cpoint(Geom::Point3d.new(0, 0, 0))
        ents.add_cpoint(Geom::Point3d.new(comprimento.cm, 0, altura.cm))
        d
      end

      def self.vao_ts(ents, xa, xb, altura, tipo, fechamento, porta, mats, pecas, ht)
        tv = pecas[:travessa]
        if porta
          # a porta traz o proprio batente ate 2,20
          return
        end

        if tipo == :testeira
          encaixar(ents, tv, longo: :x, x0: xa, x1: xb, z0: altura - ht) # topo da testeira: Travesa
          placa(ents, xa, xb, 0.0, altura - ht, mats[:ts]) unless fechamento == :estrutura
        else
          encaixar(ents, tv, longo: :x, x0: xa, x1: xb, z0: 0.0)
          encaixar(ents, tv, longo: :x, x0: xa, x1: xb, z0: altura - ht)
          placa(ents, xa, xb, ht, altura - ht, mats[:ts]) unless fechamento == :estrutura
        end
      end

      def self.vao_vidro(ents, f, xa, xb, altura, tipo, porta, mats, pecas, ht)
        meio = f[:x] + f[:largura] / 2.0
        largura_vidro = f[:largura] - (100.0 - VIDRO_LARGURA) # 99,56 no inteiro, ~49,56 no meio modulo
        vx0 = meio - largura_vidro / 2.0
        vx1 = meio + largura_vidro / 2.0
        if tipo == :testeira
          hz = altura_travessa(pecas[:z500])
          encaixar(ents, pecas[:z500], longo: :x, x0: xa, x1: xb, z0: altura - hz)
          placa(ents, vx0, vx1, VIDRO_TESTEIRA[0], VIDRO_TESTEIRA[1], mats[:vidro], VIDRO_Y, VIDRO_ESPESSURA)
          return
        end
        return if porta # porta de vidro abre o vao inteiro ate 2,20 (o vidro de cima fica na testeira)

        encaixar(ents, pecas[:travessa], longo: :x, x0: xa, x1: xb, z0: 0.0)
        VIDRO_PAREDE.each do |z0, z1|
          placa(ents, vx0, vx1, z0, z1, mats[:vidro], VIDRO_Y, VIDRO_ESPESSURA)
        end
      end

      # Fechamento que vai NA FRENTE do montante, preso por spider (vidro e MDF).
      def self.placa_frontal?(fechamento)
        %i[vidro mdf].include?(fechamento)
      end

      # Testeira de ilha (sem parede embaixo):
      #   TS:          travessa no pe, folha no meio, travessa no topo
      #   vidro / MDF: travessa no pe, placa 0,70 NA FRENTE do montante, Z500 no
      #                topo e spider (MDF segue a logica do vidro, em branco)
      def self.vao_ilha(ents, f, xa, xb, altura, fechamento, mats, pecas, ht)
        encaixar(ents, pecas[:travessa], longo: :x, x0: xa, x1: xb, z0: 0.0)
        if placa_frontal?(fechamento)
          hz = altura_travessa(pecas[:z500])
          encaixar(ents, pecas[:z500], longo: :x, x0: xa, x1: xb, z0: altura - hz)
          meio = f[:x] + f[:largura] / 2.0
          lv = f[:largura] - (100.0 - VIDRO_LARGURA)
          placa(ents, meio - lv / 2.0, meio + lv / 2.0, VIDRO_TESTEIRA[0], VIDRO_TESTEIRA[1], mats[fechamento],
                VIDRO_Y, VIDRO_ESPESSURA)
        else
          encaixar(ents, pecas[:travessa], longo: :x, x0: xa, x1: xb, z0: altura - ht)
          placa(ents, xa, xb, ht, altura - ht, mats[:ts])
        end
      end

      SPIDER_PE = 3.7 # centro do miolo do spider no pe (bloco: 1,72..5,66)

      # Braços do Spider.skp: 4 pecas, uma pra cada lado (esq/dir) e sentido
      # (sobe/desce). Montando so os bracos que tem vidro pra segurar, o spider
      # aparece so do lado do vidro (pontas, cantos, ao lado da porta).
      def self.bracos(spider)
        @bracos ||= {}
        @bracos[spider.object_id] ||= begin
          c = spider.bounds.center
          lista = spider.entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
          lista.map do |e|
            bc = e.bounds.center
            { lado: bc.x < c.x ? :esq : :dir, sentido: bc.z > c.z ? :sobe : :desce,
              defn: e.definition, tr: e.transformation }
          end
        end
      end

      def self.colocar_bracos(ents, spider, x, z_miolo, lados, sentidos)
        return if lados.empty? || sentidos.empty?

        b = spider.bounds
        mov = Geom::Transformation.translation(Geom::Vector3d.new(x.cm - b.center.x, SPIDER_Y_MIN.cm - b.min.y,
                                                                  z_miolo.cm - b.center.z))
        escolhidos = bracos(spider).select { |br| lados.include?(br[:lado]) && sentidos.include?(br[:sentido]) }
        return if escolhidos.empty?

        # os bracos de um mesmo no ficam num grupo "Spider": a Lista de pecas conta
        # spider de 1, 2 ou 4 garras
        no = [x.round(1), z_miolo.round(1)].join("|")
        g = ents.grep(Sketchup::Group).find { |e| e.get_attribute(ATRIB, "no_spider") == no }
        unless g
          g = ents.add_group
          g.set_attribute(ATRIB, "no_spider", no)
        end
        escolhidos.each { |br| g.entities.add_instance(br[:defn], mov * br[:tr]) }
        n = g.entities.grep(Sketchup::ComponentInstance).size + g.entities.grep(Sketchup::Group).size
        g.set_attribute(ATRIB, "garras", n)
        g.name = "Spider #{n} garra#{n > 1 ? 's' : ''}"
      end

      # Spiders de um trecho de vidro, em todos os eixos dele (inclusive o canto
      # que usa montante do trecho vizinho: ao virar, cada parede poe os bracos
      # do seu lado). vidro_parede[i] / vidro_testeira[i]: o vao i tem vidro?
      def self.spiders_trecho(ents, spider, eixos, vidro_parede, vidro_testeira, testeira, h_total)
        e1 = VIDRO_PAREDE[0][1] + VIDRO_FOLGA / 2.0
        e2 = VIDRO_PAREDE[1][1] + VIDRO_FOLGA / 2.0
        eixos.each_with_index do |x, k|
          lado = lambda do |tem|
            l = []
            l << :esq if k > 0 && tem[k - 1]
            l << :dir if k < tem.size && tem[k]
            l
          end
          parede = lado.call(vidro_parede)
          colocar_bracos(ents, spider, x, SPIDER_PE, parede, [:sobe])
          colocar_bracos(ents, spider, x, e1, parede, %i[sobe desce])
          if testeira
            topo = lado.call(vidro_testeira)
            colocar_bracos(ents, spider, x, e2, parede, [:desce])
            colocar_bracos(ents, spider, x, e2, topo, [:sobe])
            colocar_bracos(ents, spider, x, h_total - SPIDER_PE, topo, [:desce])
          else
            colocar_bracos(ents, spider, x, h_total - SPIDER_PE, parede, [:desce])
          end
        end
      end

      # Porta centrada no vao. Fica FORA do componente da parede e na tag
      # ESTRUTURAS: o Memorial conta "Porta Octanorm" / "Porta de vidro" como item.
      def self.colocar_porta(ents, defn, x_centro, tr_trecho, vidro, tag)
        y = vidro ? VIDRO_Y : 0.0
        inst = alinhar(ents, defn, x_centro: x_centro, y_centro: y, z_min: 0.0, tr: tr_trecho)
        inst.name = "Porta"
        inst # sem tag: a porta nao entra no Memorial (faz parte da parede/sala)
      end

      # Componente contado pelo Memorial de um trecho: parede + testeira juntas
      # (testeira escolhida junto com a parede nao vira item separado). Pontos-guia
      # marcam 0..comprimento x 0..altura total.
      def self.trecho_memorial(model, nome, chave, comprimento, h_total, partes)
        existente = model.definitions.find { |d| d.get_attribute(ATRIB, "chave") == chave }
        return existente if existente

        d = model.definitions.add(nome)
        d.set_attribute(ATRIB, "chave", chave)
        partes.each { |defn, z| d.entities.add_instance(defn, Geom::Transformation.translation(Geom::Vector3d.new(0, 0, z.cm))) }
        d.entities.add_cpoint(Geom::Point3d.new(0, 0, 0))
        d.entities.add_cpoint(Geom::Point3d.new(comprimento.cm, 0, h_total.cm))
        d
      end

      # Sala fechada: UM item no Memorial com a planta (X x Y) e a altura. So
      # pontos-guia: a caixa mede exatamente o retangulo da sala, e o nome
      # ("Deposito ... em perfil de aluminio...") faz o Memorial medir como recinto.
      def self.marcador_sala(model, nome, l, p, h)
        chave = ["v4", "sala", nome, l, p, h].join("|")
        existente = model.definitions.find { |d| d.get_attribute(ATRIB, "chave") == chave }
        return existente if existente

        d = model.definitions.add(nome)
        d.set_attribute(ATRIB, "chave", chave)
        d.entities.add_cpoint(Geom::Point3d.new(0, 0, 0))
        d.entities.add_cpoint(Geom::Point3d.new(l.cm, p.cm, h.cm))
        d
      end

      # Constroi (ou refaz) a parede. Tudo que precisa pra refazer fica gravado
      # como atributo no grupo: pontos, opcoes e onde esta a porta.
      #   porta:     :nenhuma | :octanorm | :vidro
      #   porta_pos: { trecho:, vao: } (nil = ultimo vao, Layout.porta_padrao)
      #   grupo:     grupo existente pra refazer no lugar (nil = cria novo)
      def self.construir(model, pontos:, fechado:, altura:, fechamento:, testeira:,
                         porta: :nenhuma, porta_pos: nil, grupo: nil, compartilhados: [], so_testeira: false,
                         ambiente: nil)
        trechos = Layout.trechos(pontos, fechado, compartilhados)
        sala = fechado && !so_testeira && pontos.size >= 3
        ambiente ||= grupo&.get_attribute(ATRIB, "ambiente") if sala # Mover porta / Editar mantem o nome
        ambiente = "Sala" if sala && ambiente.to_s.strip.empty?
        if so_testeira # ilha: so a faixa 2,20..2,90, sem parede nem porta
          testeira = true
          porta = :nenhuma
        end
        meio = true # TS (0,50) e vidro (0,49) tem meio modulo
        porta_pos ||= Layout.porta_padrao(trechos, meio: meio) if porta != :nenhuma
        porta = :nenhuma if porta_pos.nil?

        mats = materiais(model)
        pecas = { montante: peca(model, :montante), travessa: peca(model, :travessa) }
        if placa_frontal?(fechamento)
          pecas[:z500] = peca(model, :z500)
          pecas[:spider] = peca(model, :spider)
        end
        porta_def = case porta
                    when :octanorm then peca(model, :porta_octanorm)
                    when :vidro then peca(model, :porta_vidro)
                    end
        tag = model.layers[TAG] || model.layers.add(TAG)
        fch = FECHAMENTOS[fechamento]
        h_total = testeira ? altura + TESTEIRA_ALTURA : altura

        if grupo
          grupo.make_unique if grupo.definition.count_instances > 1 # copia da sala: nao mexe nas outras
          grupo.entities.clear!
        else
          grupo = model.active_entities.add_group
        end
        grupo.name = so_testeira ? "Testeira ilha #{fch[:rotulo]}" : "Octanorm #{fch[:rotulo]} #{Layout.metros(h_total)} m"
        { "pontos" => JSON.generate(pontos), "fechado" => fechado, "altura" => altura,
          "fechamento" => fechamento.to_s, "testeira" => testeira, "porta" => porta.to_s,
          "porta_pos" => (porta_pos ? JSON.generate(porta_pos) : nil),
          "compartilhados" => JSON.generate(compartilhados), "so_testeira" => so_testeira,
          "ambiente" => (sala ? ambiente : nil) }.each { |k, v| grupo.set_attribute(ATRIB, k, v) }
        grupo.name = "#{ambiente} (Octanorm #{fch[:rotulo]} #{Layout.metros(h_total)} m)" if sala
        tag_trecho = sala ? nil : tag # sala: quem conta e o marcador da sala, nao os trechos

        # vidro/MDF sempre pro lado de fora, em qualquer sentido de desenho
        espelho = Layout.horario?(pontos) ? Geom::Transformation.scaling(ORIGIN, 1, -1, 1) : Geom::Transformation.new
        trechos.each_with_index do |t, ti|
          c = t[:comprimento]
          origem = Geom::Point3d.new(t[:inicio][0].cm, t[:inicio][1].cm, 0)
          tr = Geom::Transformation.translation(origem) * Geom::Transformation.rotation(ORIGIN, Z_AXIS, t[:angulo]) * espelho

          # montantes (e spiders do vidro) fora do componente da parede, sem tag
          eixos = Layout.folhas(c, meio: meio)[:folhas].map { |f| f[:x] + f[:largura] }
          eixos.unshift(0.0) if t[:montante_inicio]
          eixos.pop unless t[:montante_fim] # encostou num montante de outra parede
          g_m = grupo.entities.add_group
          g_m.name = placa_frontal?(fechamento) ? "Montantes e spiders" : "Montantes"
          eixos.each do |x|
            # ilha: so canto e ponta descem ate o chao (sustentam); os do meio ficam na faixa
            apoio = (x.abs < 0.01 && t[:montante_inicio]) || ((x - c).abs < 0.01 && t[:montante_fim])
            z0 = so_testeira && !apoio ? altura : 0
            encaixar(g_m.entities, pecas[:montante], longo: :z, x0: x, z0: z0, z1: h_total)
          end
          g_m.transformation = tr

          if so_testeira
            if placa_frontal?(fechamento)
              fs = Layout.folhas(c, meio: meio)[:folhas]
              ([0.0] + fs.map { |f| f[:x] + f[:largura] }).each_with_index do |x, k|
                lados = []
                lados << :esq if k > 0
                lados << :dir if k < fs.size
                colocar_bracos(g_m.entities, pecas[:spider], x, altura + SPIDER_PE, lados, [:sobe])
                colocar_bracos(g_m.entities, pecas[:spider], x, h_total - SPIDER_PE, lados, [:desce])
              end
            end
            nome_i = Layout.nome_memorial("Testeira", fechamento) # testeira sozinha: item proprio
            chave_i = ["v4", "ilha", fechamento, c].join("|")
            di = definicao(model, nome_i, chave_i, c, TESTEIRA_ALTURA, fechamento, :ilha, mats, pecas)
            tr_i = Geom::Transformation.translation(Geom::Vector3d.new(0, 0, altura.cm)) * tr
            grupo.entities.add_instance(di, tr_i).layer = tag
            next
          end

          vao_p = porta != :nenhuma && porta_pos[:trecho] == ti ? porta_pos[:vao] : nil

          if fechamento == :vidro
            fs = Layout.folhas(c, meio: meio)[:folhas]
            todos_eixos = [0.0] + fs.map { |f| f[:x] + f[:largura] } # inclui canto/ponta de outro trecho
            vidro_parede = fs.each_index.map { |i| i != vao_p } # vao da porta: sem vidro ate 2,20
            vidro_testeira = fs.map { true }                     # testeira de vidro passa por cima da porta
            spiders_trecho(g_m.entities, pecas[:spider], todos_eixos, vidro_parede, vidro_testeira, testeira, h_total)
          end

          # pecas da parede e da testeira (nao contam sozinhas) dentro de um
          # componente do trecho, que e o que o Memorial conta
          nome_p = "#{fch[:nome]} #{Layout.metros(c)} x #{Layout.metros(altura)} m"
          chave_p = ["parede", fechamento, c, altura, vao_p].join("|")
          dp = definicao(model, nome_p, chave_p, c, altura, fechamento, :parede, mats, pecas, vao_p)
          partes = [[dp, 0.0]]
          chave_t = nil
          if testeira
            nome_t = "#{fch[:testeira]} #{Layout.metros(c)} x #{Layout.metros(TESTEIRA_ALTURA)} m"
            chave_t = ["testeira", fechamento, c].join("|")
            partes << [definicao(model, nome_t, chave_t, c, TESTEIRA_ALTURA, fechamento, :testeira, mats, pecas), altura]
          end
          dtr = trecho_memorial(model, Layout.nome_memorial("Parede", fechamento),
                                ["v4", "trecho", chave_p, chave_t].join("|"), c, h_total, partes)
          inst = grupo.entities.add_instance(dtr, tr)
          inst.layer = tag_trecho if tag_trecho

          next unless vao_p

          f = Layout.folhas(c, meio: meio)[:folhas][vao_p]
          colocar_porta(grupo.entities, porta_def, f[:x] + f[:largura] / 2.0, tr, fechamento == :vidro, tag)
        end

        if sala
          r = Layout.retangulo_da_sala(pontos)
          marc = marcador_sala(model, Layout.nome_memorial(ambiente, fechamento), r[:l], r[:p], h_total)
          tr_s = Geom::Transformation.translation(Geom::Vector3d.new(r[:origem][0].cm, r[:origem][1].cm, 0)) *
                 Geom::Transformation.rotation(ORIGIN, Z_AXIS, r[:angulo])
          m = grupo.entities.add_instance(marc, tr_s)
          m.layer = tag
          m.name = ambiente
        end
        grupo
      end
    end
  end
end
