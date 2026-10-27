# encoding: UTF-8
# =============================================================================
# STAND1 Octanorm — teto.rb
# Teto grid Z500 (pergolado metalico) que se adapta ao estande: grade de
# modulos 1,00 x 1,00 m (meio modulo de 0,50 quando sobra), Z500 entre os nos e
# um pedaco de montante Octanorm em cada no. Topo em 2,90 (em cima da testeira)
# ou 2,20 (em cima da parede).
#
# Se adapta ao que ja esta no modelo:
#   lado em cima de parede da mesma altura -> sem viga e sem no (o topo da
#     parede ja fecha a borda e os montantes dela seguram o teto)
#   canto que nao encosta em parede -> montante ate o chao
#
# Memorial: um componente "Teto grid Z500 L x P m" na tag ESTRUTURAS, so com
# as vigas e pontos-guia pra caixa medir L x P (a regra "teto" do Memorial da
# o m2). Nos e montantes ate o chao ficam fora dele, sem tag (igual aos da parede).
# =============================================================================
require 'json'

module STAND1
  module Octanorm
    module Teto
      ATRIB = Geometria::ATRIB
      ALTURAS = { "2,90 (em cima da testeira)" => 290.0, "2,20 (em cima da parede)" => 220.0 }.freeze
      FORROS = { "Sem forro" => nil, "Forro eucatex" => "eucatex" }.freeze
      NOME = "Teto em perfil de alumínio Z500".freeze # "teto": o Memorial mede L x P
      NOME_FORRO = "Forro em eucatex".freeze           # "forro": item separado, L x P
      EUCATEX_ESPESSURA = 0.3 # cm

      # Placa de eucatex em cada modulo da grade, apoiada em cima das Z500.
      def self.definicao_forro(model, l, p, h)
        chave = ["v4", "forro", "eucatex", l, p, h].join("|")
        existente = model.definitions.find { |d| d.get_attribute(ATRIB, "chave") == chave }
        return existente if existente

        mat = Geometria.material(model, "Forro Eucatex Branco", [238, 238, 232])
        d = model.definitions.add(NOME_FORRO)
        d.set_attribute(ATRIB, "chave", chave)
        Layout.grade(l).each_cons(2) do |x0, x1|
          Layout.grade(p).each_cons(2) do |y0, y1|
            g = d.entities.add_group
            cantos = [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]
            f = g.entities.add_face(cantos.map { |x, y| Geom::Point3d.new(x.cm, y.cm, h.cm) })
            f.reverse! if f.normal.z < 0
            f.pushpull(EUCATEX_ESPESSURA.cm)
            g.material = mat
          end
        end
        d.entities.add_cpoint(Geom::Point3d.new(0, 0, h.cm))
        d.entities.add_cpoint(Geom::Point3d.new(l.cm, p.cm, (h + EUCATEX_ESPESSURA).cm))
        d
      end

      # Z500 esticada de a ate b (cm, no plano), com a base em z0
      def self.viga(ents, defn, a, b, z0)
        comp = Math.hypot(b[0] - a[0], b[1] - a[1])
        return nil if comp < 0.5

        b0 = defn.bounds
        maior = { x: b0.width, y: b0.height, z: b0.depth }.max_by { |_k, v| v }[0]
        rot = case maior
              when :y then Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees)
              when :z then Geom::Transformation.rotation(ORIGIN, Y_AXIS, 90.degrees)
              else Geom::Transformation.new
              end
        bb = Geometria.caixa_girada(defn, rot)
        ref = Geom::Point3d.new(bb.min.x, bb.center.y, bb.min.z)
        ang = Math.atan2(b[1] - a[1], b[0] - a[0])
        tr = Geom::Transformation.translation(Geom::Vector3d.new(a[0].cm, a[1].cm, z0.cm)) *
             Geom::Transformation.rotation(ORIGIN, Z_AXIS, ang) *
             Geom::Transformation.scaling(ORIGIN, comp.cm / bb.width, 1, 1) *
             Geom::Transformation.translation(ORIGIN - ref) * rot
        ents.add_instance(defn, tr)
      end

      # pedaco de montante em pe, centrado em (x, y), de z0 a z1
      def self.no(ents, defn, x, y, z0, z1)
        inst = Geometria.encaixar(ents, defn, longo: :z, x0: 0.0, z0: z0, z1: z1)
        inst.transform!(Geom::Transformation.translation(Geom::Vector3d.new(x.cm, y.cm, 0)))
        inst
      end

      # Paredes do plugin no contexto: segmentos [a, b, topo] e montantes
      # [x, y, topo] (cm, coordenadas do contexto). Procura dentro de grupos.
      def self.paredes(ents, tr = Geom::Transformation.new, nivel = 0, saida = { segmentos: [], montantes: [] })
        ents.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)

          t = tr * e.transformation
          pts = e.get_attribute(ATRIB, "pontos")
          if pts
            topo = e.get_attribute(ATRIB, "altura").to_f
            topo += Geometria::TESTEIRA_ALTURA if e.get_attribute(ATRIB, "testeira")
            comp = e.get_attribute(ATRIB, "compartilhados")
            trechos = Layout.trechos(JSON.parse(pts), e.get_attribute(ATRIB, "fechado") ? true : false,
                                     comp ? JSON.parse(comp) : [])
            mundo = lambda do |xy|
              q = Geom::Point3d.new(xy[0].cm, xy[1].cm, 0).transform(t)
              [q.x.to_cm, q.y.to_cm]
            end
            trechos.each { |tc| saida[:segmentos] << [mundo.call(tc[:inicio]), mundo.call(tc[:fim]), topo] }
            Layout.eixos(trechos).each { |xy| saida[:montantes] << mundo.call(xy) + [topo] }
          elsif nivel < 4 && e.get_attribute(ATRIB, "tipo") != "teto"
            paredes(e.definition.entities, t, nivel + 1, saida)
          end
        end
        saida
      end

      # Componente contado pelo Memorial: so as vigas. A viga da borda entra meia
      # espessura pra dentro, entao a caixa (com os pontos-guia) mede L x P certinho.
      def self.definicao(model, nome, chave, l, p, h, pecas, vigas)
        existente = model.definitions.find { |d| d.get_attribute(ATRIB, "chave") == chave }
        return existente if existente

        d = model.definitions.add(nome)
        d.set_attribute(ATRIB, "chave", chave)
        e = d.entities
        hz = Geometria.altura_travessa(pecas[:z500])
        m = Geometria.largura_montante(pecas[:montante]) / 2.0
        meia = Geometria.largura_montante(pecas[:z500]) / 2.0 # menor medida da peca = espessura da Z500
        z0 = h - hz
        borda = ->(c1, c2, fim) { c1.abs < 0.01 && c2.abs < 0.01 ? meia : ((c1 - fim).abs < 0.01 && (c2 - fim).abs < 0.01 ? -meia : 0.0) }
        vigas.each do |a, b|
          u = Layout.unitario(a, b)
          dx = borda.call(a[0], b[0], l)
          dy = borda.call(a[1], b[1], p)
          viga(e, pecas[:z500], [a[0] + u[0] * m + dx, a[1] + u[1] * m + dy],
               [b[0] - u[0] * m + dx, b[1] - u[1] * m + dy], z0)
        end
        # pontos-guia: a caixa do componente mede exatamente L x P
        e.add_cpoint(Geom::Point3d.new(0, 0, z0.cm))
        e.add_cpoint(Geom::Point3d.new(l.cm, p.cm, h.cm))
        d
      end

      # Constroi (ou refaz no mesmo grupo). origem [x, y] cm e angulo (rad) no
      # sistema do contexto onde o grupo esta.
      def self.construir(model, origem:, angulo:, l:, p:, altura:, grupo: nil, forro: nil)
        raise ArgumentError, "teto pequeno demais (minimo 0,50 x 0,50 m)" if l < 50 || p < 50

        pecas = { montante: Geometria.peca(model, :montante), z500: Geometria.peca(model, :z500) }
        tag = model.layers[Geometria::TAG] || model.layers.add(Geometria::TAG)

        # paredes da mesma altura, levadas pro sistema do teto
        ctx = grupo ? grupo.parent.entities : model.active_entities
        local = grupo ? grupo.transformation.inverse : Geom::Transformation.new
        achadas = paredes(ctx)
        no_teto = lambda do |xy|
          q = Geom::Point3d.new(xy[0].cm, xy[1].cm, 0).transform(local)
          Layout.no_teto([q.x.to_cm, q.y.to_cm], origem, angulo)
        end
        mesma = ->(topo) { (topo - altura).abs < 1.0 }
        segs = achadas[:segmentos].select { |s| mesma.call(s[2]) }.map { |s| [no_teto.call(s[0]), no_teto.call(s[1])] }
        monts = achadas[:montantes].select { |q| mesma.call(q[2]) }.map { |q| no_teto.call(q) }
        lados = Layout.lados_cobertos(l, p, segs)
        soltos = Layout.cantos_soltos(l, p, segs)
        pecas_teto = Layout.teto_pecas(l, p, lados, soltos)

        if grupo
          grupo.make_unique if grupo.definition.count_instances > 1 # copia do teto: nao mexe nas outras
          grupo.entities.clear!
        else
          grupo = model.active_entities.add_group
        end
        grupo.name = "Teto grid Z500 #{Layout.metros(l)} x #{Layout.metros(p)} m"
        { "tipo" => "teto", "origem" => JSON.generate(origem), "angulo" => angulo, "l" => l, "p" => p,
          "altura" => altura, "vigas" => pecas_teto[:vigas].size, "nos" => pecas_teto[:nos].size,
          "montantes" => soltos.size, "lados" => lados.count(true),
          "sem_montante" => Layout.pontas_sem_montante(l, p, lados, monts), "forro" => forro }.each { |k, v| grupo.set_attribute(ATRIB, k, v) }

        tr = Geom::Transformation.translation(Geom::Vector3d.new(origem[0].cm, origem[1].cm, 0)) *
             Geom::Transformation.rotation(ORIGIN, Z_AXIS, angulo)
        chave = ["v4", "teto", l, p, altura, lados.join(","), soltos.flatten.join(",")].join("|")
        grupo.entities.add_instance(definicao(model, NOME, chave, l, p, altura, pecas, pecas_teto[:vigas]), tr).layer = tag
        # forro: item proprio no Memorial ("Forro em eucatex", L x P)
        grupo.entities.add_instance(definicao_forro(model, l, p, altura), tr).layer = tag if forro == "eucatex"

        # nos (pedaco de montante no cruzamento) e montantes ate o chao: fora do
        # componente e sem tag, igual aos montantes da parede
        if pecas_teto[:nos].any? || soltos.any?
          hz = Geometria.altura_travessa(pecas[:z500])
          g = grupo.entities.add_group
          g.name = soltos.any? ? "Nos e montantes do teto" : "Nos do teto"
          pecas_teto[:nos].each { |x, y| no(g.entities, pecas[:montante], x, y, altura - hz, altura) }
          soltos.each { |x, y| no(g.entities, pecas[:montante], x, y, 0.0, altura) }
          g.transformation = tr
        end
        grupo
      end

      # Teto em cima de uma sala, ilha ou parede em L feita pelo plugin: pega o
      # retangulo e a altura dela (2,20 ou 2,90 com testeira).
      def self.construir_da_sala(model, sala, forro: nil)
        pts = JSON.parse(sala.get_attribute(ATRIB, "pontos"))
        r = Layout.retangulo_da_sala(pts)
        t = sala.transformation
        o = Geom::Point3d.new(r[:origem][0].cm, r[:origem][1].cm, 0).transform(t)
        altura = sala.get_attribute(ATRIB, "altura").to_f
        altura += Geometria::TESTEIRA_ALTURA if sala.get_attribute(ATRIB, "testeira")
        construir(model, origem: [o.x.to_cm, o.y.to_cm], angulo: r[:angulo] + Math.atan2(t.xaxis.y, t.xaxis.x),
                         l: r[:l], p: r[:p], altura: altura, forro: forro)
      end

      def self.relatorio(grupo)
        a = ->(k) { grupo.get_attribute(ATRIB, k) }
        l = a.call("l").to_f
        p = a.call("p").to_f
        txt = "Teto grid Z500: #{Layout.metros(l)} x #{Layout.metros(p)} m (#{Layout.fmt((l * p / 10_000.0).round(2))} m2)\n\n"
        txt << "Topo em #{Layout.metros(a.call('altura'))} m\n"
        txt << "Modulos: #{Layout.grade(l).size - 1} x #{Layout.grade(p).size - 1}\n"
        txt << "Vigas Z500: #{a.call('vigas')}\n"
        txt << "Nos (montante curto): #{a.call('nos')}\n"
        txt << "Lados em cima de parede: #{a.call('lados')} de 4\n"
        txt << "Montantes ate o chao (cantos soltos): #{a.call('montantes')}\n"
        if a.call("forro") == "eucatex"
          txt << "Forro eucatex: #{(Layout.grade(l).size - 1) * (Layout.grade(p).size - 1)} placa(s), item proprio no Memorial\n"
        end
        avisos = []
        if a.call("sem_montante").to_i > 0
          avisos << "#{a.call('sem_montante')} ponta(s) de viga em cima de parede sem montante embaixo " \
                    "(meio modulo em ponta diferente na parede oposta?)"
        end
        if (Layout.folhas(l)[:folhas] + Layout.folhas(p)[:folhas]).any? { |f| f[:especial] }
          avisos << "modulo especial (fora de 1,00 / 0,50) num dos lados"
        end
        txt << "\nAtencao:\n- " + avisos.join("\n- ") if avisos.any?
        UI.messagebox(txt)
      end
    end

    # Teto sem sala selecionada: dois cliques (cantos opostos) ou digitar a
    # medida (ex.: 4x3). Gruda nos montantes das paredes existentes (mesmo ima
    # da ferramenta de parede).
    class FerramentaTeto < Ferramenta
      def status
        Sketchup.status_text = if @pts.empty?
                                 "Teto grid Z500: clique o 1o canto (gruda nos montantes das paredes)."
                               else
                                 "Clique o canto oposto ou digite a medida (ex.: 4x3 ou 3,5 x 2). " \
                                 "Backspace recomeca. Esc cancela."
                               end
        Sketchup.vcb_label = "Medida (L x P)"
      end

      # teto sempre no eixo do modelo: sem orto
      def ortogonal(p)
        @eixo = nil
        p
      end

      def onMouseMove(flags, x, y, view)
        super
        return unless @pts.any? && @atual

        a = @pts.first
        Sketchup.vcb_value = "#{Layout.metros((@atual.x - a.x).abs.to_cm)} x #{Layout.metros((@atual.y - a.y).abs.to_cm)}"
      end

      def onLButtonDown(_flags, _x, _y, view)
        return unless @atual

        if @pts.empty?
          @pts << @atual
          @ip_ant = Sketchup::InputPoint.new(@atual)
          status
        else
          criar(view, @pts.first, @atual)
        end
        view.invalidate
      end

      def onLButtonDoubleClick(_flags, _x, _y, _view); end

      def onReturn(_view); end

      def onKeyDown(key, _repeat, _flags, view)
        return unless key == TECLA_BACKSPACE && @pts.any?

        resetar
        view.invalidate
      end

      def onUserText(texto, view)
        return UI.beep if @pts.empty?

        dims = Layout.ler_dimensoes(texto)
        unless dims
          UI.beep
          Sketchup.status_text = "Medida nao entendida. Ex.: 4x3 (metros) ou 400x300cm."
          return
        end
        a = @pts.first
        sx = @atual && @atual.x < a.x ? -1 : 1
        sy = @atual && @atual.y < a.y ? -1 : 1
        criar(view, a, Geom::Point3d.new(a.x + sx * dims[0].cm, a.y + sy * dims[1].cm, 0))
      end

      def criar(view, a, b)
        x0, x1 = [a.x, b.x].minmax
        y0, y1 = [a.y, b.y].minmax
        l = (x1 - x0).to_cm.round(1)
        p = (y1 - y0).to_cm.round(1)
        if l < 50 || p < 50
          UI.beep
          Sketchup.status_text = "Teto pequeno demais (minimo 0,50 x 0,50 m)."
          return
        end
        model = Sketchup.active_model
        model.start_operation("STAND1 Octanorm: teto grid Z500", true)
        begin
          g = Teto.construir(model, origem: [x0.to_cm.round(1), y0.to_cm.round(1)], angulo: 0.0, l: l, p: p,
                                    altura: @opcoes[:altura], forro: @opcoes[:forro])
          model.commit_operation
        rescue StandardError => e
          model.abort_operation
          UI.messagebox("Erro ao montar o teto:\n#{e.message}")
          resetar
          return
        end
        Teto.relatorio(g)
        resetar
        view.invalidate
      end

      def draw(view)
        @ip.draw(view) if @ip.valid?
        if @no_ima && @atual
          view.draw_points([@atual], 22, 1, COR_ROSA)
          view.draw_points([@atual], 8, 2, COR_ROSA)
        end
        return if @pts.empty? || @atual.nil?

        a = @pts.first
        b = @atual
        view.line_width = 2
        view.drawing_color = COR_AZUL
        view.draw(GL_LINE_STRIP, [a, Geom::Point3d.new(b.x, a.y, 0), b, Geom::Point3d.new(a.x, b.y, 0), a])
        l = (b.x - a.x).abs.to_cm
        p = (b.y - a.y).abs.to_cm
        return if l < 50 || p < 50

        # previa da grade de 1,00 m
        sx = b.x < a.x ? -1 : 1
        sy = b.y < a.y ? -1 : 1
        view.line_stipple = "-"
        view.line_width = 1
        Layout.grade(l).each do |g|
          x = a.x + sx * g.cm
          view.draw(GL_LINES, [Geom::Point3d.new(x, a.y, 0), Geom::Point3d.new(x, b.y, 0)])
        end
        Layout.grade(p).each do |g|
          y = a.y + sy * g.cm
          view.draw(GL_LINES, [Geom::Point3d.new(a.x, y, 0), Geom::Point3d.new(b.x, y, 0)])
        end
        view.line_stipple = ""
      end

      def getMenu(menu)
        view = Sketchup.active_model.active_view
        menu.add_item("Recomecar  [Backspace]") { resetar; view.invalidate }
        menu.add_item("Cancelar  [Esc]") { resetar; view.invalidate }
        true
      end
    end
  end
end
