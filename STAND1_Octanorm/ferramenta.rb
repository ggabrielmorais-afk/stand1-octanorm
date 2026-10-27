# encoding: UTF-8
# =============================================================================
# STAND1 Octanorm — ferramenta.rb
# Ferramenta de clique (estilo Fence Maker): clica os pontos no piso, a parede
# e montada sozinha.
#   clique ............ adiciona ponto
#   clique no 1o ponto  fecha a sala
#   duplo clique/Enter  termina parede aberta
#   digitar medida .... comprimento do proximo trecho (ex.: 300 ou 3m)
#   Esc ............... cancela os pontos
# =============================================================================

require 'json'

module STAND1
  module Octanorm
    class Ferramenta
      FECHAR_RAIO_CM = 15.0
      # paleta dos plugins STAND1 do Tarcisio (Memorial / EVA)
      COR_AZUL = Sketchup::Color.new(26, 45, 184)  # --azul #1A2DB8
      COR_ROSA = Sketchup::Color.new(230, 57, 138) # --g-rosa #e6398a

      def initialize(opcoes)
        @opcoes = opcoes
        @ip = Sketchup::InputPoint.new
        resetar
      end

      def resetar
        @pts = []
        @atual = nil
        @ip_ant = nil
        @eixo = nil
        @no_ima = false
        @compartilhados = []
        carregar_imas
        Sketchup.active_model.active_view.invalidate if Sketchup.active_model
        status
      end

      def status
        Sketchup.status_text = if @pts.empty?
                                 "STAND1 Octanorm: clique o ponto inicial da parede."
                               else
                                 "Clique o proximo ponto. F (ou clicar no 1o ponto) fecha a sala. Backspace desfaz. " \
                                 "Duplo clique ou Enter termina. Digite a medida em metros (ex.: 3 ou 2,5). " \
                                 "Shift trava no eixo. Quadrado rosa = encostou num montante existente."
                               end
        Sketchup.vcb_label = "Comprimento"
      end

      def activate
        resetar
      end

      def deactivate(view)
        view.invalidate
      end

      def enableVCB?
        true
      end

      IMA_PIXELS = 25    # perto disso (na tela) de um montante, gruda nele
      TRILHO_PIXELS = 18 # perto disso de uma parede existente, desliza de montante em montante

      # Montantes das paredes Octanorm que ja estao no modelo viram "ima": a parede
      # nova encosta neles, fecha neles e nao duplica o montante. Procura tambem
      # dentro de grupos/componentes (stand agrupado), ate 4 niveis.
      def carregar_imas
        @imas = []
        @trilhos = [] # por trecho: lista ordenada dos montantes (pra deslizar na parede)
        model = Sketchup.active_model
        return unless model

        procurar_paredes(model.active_entities, Geom::Transformation.new, 0)
      rescue StandardError => e
        puts "STAND1 Octanorm: ima nao carregou (#{e.message})"
        @imas ||= []
        @trilhos ||= []
      end

      def procurar_paredes(ents, tr, nivel)
        ents.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)

          t = tr * e.transformation
          pts = e.get_attribute(Geometria::ATRIB, "pontos")
          if pts
            comp = e.get_attribute(Geometria::ATRIB, "compartilhados")
            trechos = Layout.trechos(JSON.parse(pts), e.get_attribute(Geometria::ATRIB, "fechado") ? true : false,
                                     comp ? JSON.parse(comp) : [])
            mundo = ->(xy) { Geom::Point3d.new(xy[0].cm, xy[1].cm, 0).transform(t) }
            Layout.eixos(trechos).each { |xy| @imas << mundo.call(xy) }
            trechos.each { |tc| @trilhos << Layout.eixos([tc]).map { |xy| mundo.call(xy) } }
          elsif nivel < 4
            filhos = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
            procurar_paredes(filhos, t, nivel + 1)
          end
        end
      end

      def dist_tela_segmento(view, tela, a, b)
        pa = view.screen_coords(a)
        pb = view.screen_coords(b)
        dx = pb.x - pa.x
        dy = pb.y - pa.y
        l2 = dx * dx + dy * dy
        return pa.distance(tela) if l2 < 1e-6

        u = (((tela.x - pa.x) * dx + (tela.y - pa.y) * dy) / l2).clamp(0.0, 1.0)
        Geom::Point3d.new(pa.x + u * dx, pa.y + u * dy, 0).distance(tela)
      end

      # 1) montante perto (ou o 1o ponto do desenho, pra fechar a sala)
      # 2) cursor encostado numa parede: vai pro montante mais perto dela
      def ima_perto(view, x, y)
        tela = Geom::Point3d.new(x, y, 0)
        perto = ->(p) { view.screen_coords(p).distance(tela) }
        candidatos = @imas.dup
        candidatos << @pts.first if @pts.size >= 2
        p = candidatos.min_by { |c| perto.call(c) }
        return p if p && perto.call(p) <= IMA_PIXELS

        trilho = @trilhos.select { |tr| tr.size >= 2 && dist_tela_segmento(view, tela, tr.first, tr.last) <= TRILHO_PIXELS }
                         .min_by { |tr| dist_tela_segmento(view, tela, tr.first, tr.last) }
        trilho&.min_by { |c| perto.call(c) }
      end

      def no_piso(pt)
        Geom::Point3d.new(pt.x, pt.y, 0)
      end

      ORTO_GRAUS = 6.0 # perto disso de um eixo, trava no eixo

      # Orto: trava a direcao no eixo vermelho (X) ou verde (Y) quando o mouse
      # esta perto dele, ou sempre que o Shift estiver apertado.
      def ortogonal(p)
        @eixo = nil
        return p if @pts.empty?

        o = @pts.last
        dx = p.x - o.x
        dy = p.y - o.y
        return p if dx.abs < 0.001 && dy.abs < 0.001

        ang = Math.atan2(dy.abs, dx.abs) * 180.0 / Math::PI # 0 = eixo X, 90 = eixo Y
        if @shift || ang < ORTO_GRAUS || ang > 90 - ORTO_GRAUS
          if ang < 45
            @eixo = :x
            return Geom::Point3d.new(p.x, o.y, 0)
          else
            @eixo = :y
            return Geom::Point3d.new(o.x, p.y, 0)
          end
        end
        p
      end

      def onKeyDown(key, _repeat, _flags, view)
        return fechar_sala(view) if key == TECLA_F && @pts.any?
        return desfazer_ponto(view) if key == TECLA_BACKSPACE && @pts.any?
        return unless key == CONSTRAIN_MODIFIER_KEY

        @shift = true
        view.invalidate
      end

      def onKeyUp(key, _repeat, _flags, view)
        return unless key == CONSTRAIN_MODIFIER_KEY

        @shift = false
        view.invalidate
      end

      def onMouseMove(_flags, x, y, view)
        # passa o ultimo ponto clicado: o SketchUp faz a inferencia de eixo e de ponto
        @ip.pick(view, x, y, @ip_ant)
        @atual = ortogonal(no_piso(@ip.position))
        ima = ima_perto(view, x, y)
        @no_ima = !ima.nil?
        if ima
          @atual = Geom::Point3d.new(ima.x, ima.y, 0)
          @eixo = nil
        end
        view.tooltip = "Montante (ima)" if ima
        if @pts.any?
          Sketchup.vcb_value = Layout.metros(@pts.last.distance(@atual).to_cm) + " m"
        end
        view.tooltip = @ip.tooltip unless @no_ima
        view.invalidate
      end

      def onLButtonDown(_flags, _x, _y, view)
        return unless @atual

        if @pts.size >= 3 && @atual.distance(@pts.first).to_cm < FECHAR_RAIO_CM
          terminar(view, true)
        else
          @pts << @atual
          @compartilhados << [@atual.x.to_cm, @atual.y.to_cm] if @no_ima
          @ip_ant = Sketchup::InputPoint.new(@atual)
          status
        end
        view.invalidate
      end

      def onLButtonDoubleClick(_flags, _x, _y, view)
        terminar(view, false)
      end

      def onReturn(view)
        terminar(view, false)
      end

      # F = fecha a sala (liga o ultimo ponto no primeiro); Backspace = desfaz ponto
      TECLA_F = 70
      TECLA_BACKSPACE = 8

      def fechar_sala(view)
        if @pts.size >= 3
          terminar(view, true)
        else
          UI.beep
          Sketchup.status_text = "Pra fechar a sala precisa de pelo menos 3 pontos."
        end
      end

      def desfazer_ponto(view)
        @pts.pop
        @compartilhados.reject! { |c| @pts.none? { |p| (p.x.to_cm - c[0]).abs < 1 && (p.y.to_cm - c[1]).abs < 1 } }
        @ip_ant = @pts.any? ? Sketchup::InputPoint.new(@pts.last) : nil
        status
        view.invalidate
      end

      # botao direito durante o desenho
      def getMenu(menu)
        view = Sketchup.active_model.active_view
        menu.add_item("Fechar sala (ligar no inicio)  [F]") { fechar_sala(view) }
        menu.add_item("Terminar parede aberta  [Enter]") { terminar(view, false) }
        menu.add_item("Desfazer ultimo ponto  [Backspace]") { desfazer_ponto(view) }
        menu.add_item("Cancelar  [Esc]") { resetar; view.invalidate }
        true
      end

      def onCancel(_reason, view)
        resetar
        view.invalidate
      end

      # medida digitada: crava o proximo ponto na direcao do mouse
      def onUserText(texto, view)
        return if @pts.empty? || @atual.nil?

        cm = Layout.ler_medida(texto) # numero sozinho = metros ("3" = 3,00 m)
        unless cm
          UI.beep
          Sketchup.status_text = "Medida nao entendida. Digite em metros (ex.: 3 ou 2,5) ou com unidade (300cm)."
          return
        end
        comp = cm.cm
        dir = @pts.last.vector_to(@atual)
        return UI.beep unless dir.valid?

        dir.length = comp
        @pts << @pts.last.offset(dir)
        @ip_ant = Sketchup::InputPoint.new(@pts.last)
        status
        view.invalidate
      end

      def draw(view)
        @ip.draw(view) if @ip.valid?
        # ima: quadrado verde quando o cursor gruda num montante de parede existente
        # ima: anel rosa grande quando o cursor gruda num montante
        if @no_ima && @atual
          view.draw_points([@atual], 22, 1, COR_ROSA)
          view.draw_points([@atual], 8, 2, COR_ROSA)
        end
        caminho = @pts + (@atual ? [@atual] : [])
        return if caminho.size < 2

        view.line_width = 3
        view.drawing_color = COR_AZUL
        view.draw(GL_LINE_STRIP, @pts) if @pts.size >= 2
        # trecho que esta sendo desenhado: vermelho/verde quando travado no eixo (orto)
        if @atual && @pts.any?
          view.drawing_color = case @eixo
                               when :x then Sketchup::Color.new(220, 0, 0)
                               when :y then Sketchup::Color.new(0, 160, 0)
                               else COR_AZUL
                               end
          view.draw(GL_LINES, [@pts.last, @atual])
        end
        # tracejado ate o 1o ponto: mostra como a sala fecha (F ou clicar no 1o ponto)
        if @pts.size >= 3 && @atual
          view.line_stipple = "-"
          view.line_width = 1
          view.drawing_color = Sketchup::Color.new(120, 120, 120)
          view.draw(GL_LINES, [@atual, @pts.first])
          view.line_stipple = ""
          view.line_width = 3
        end
        if @pts.size >= 3 && @atual && @atual.distance(@pts.first).to_cm < FECHAR_RAIO_CM
          view.drawing_color = COR_ROSA
          view.draw_points([@pts.first], 14, 2, view.drawing_color)
        end
      end

      def getExtents
        bb = Geom::BoundingBox.new
        (@pts + (@atual ? [@atual] : [])).each { |p| bb.add(p) }
        bb
      end

      # Sala fechada vira UM item no Memorial: o tipo (Sala/Deposito/Copa/Cabine)
      # faz ele medir como recinto, 2 x (X + Y) x altura. Cancelar = "Sala".
      @ultimo_ambiente = ["Sala", ""]

      def self.perguntar_ambiente(padrao = nil)
        valores = padrao || @ultimo_ambiente
        r = UI.inputbox(["Tipo de ambiente", "Complemento (opcional, ex.: de reuniao)"], valores,
                        [Layout::AMBIENTES.keys.join("|"), ""], "STAND1 Octanorm: nome da sala")
        return Layout.nome_ambiente(valores[0], valores[1]) unless r

        @ultimo_ambiente = [r[0], ""]
        Layout.nome_ambiente(r[0], r[1])
      end

      def terminar(view, fechado)
        pts = @pts.dup
        if pts.size < 2
          resetar
          return
        end
        cm = pts.map { |p| [p.x.to_cm, p.y.to_cm] }
        trechos = Layout.trechos(cm, fechado)
        ambiente = fechado && !@opcoes[:so_testeira] ? Ferramenta.perguntar_ambiente : nil
        model = Sketchup.active_model
        model.start_operation("STAND1 Octanorm", true)
        begin
          Geometria.construir(model, pontos: cm, fechado: fechado, compartilhados: @compartilhados, ambiente: ambiente,
                                     **@opcoes)
          model.commit_operation
        rescue => e
          model.abort_operation
          UI.messagebox("Erro ao montar a parede:\n#{e.message}")
          resetar
          return
        end
        Octanorm.relatorio(trechos, @opcoes)
        resetar
        view.invalidate
      end
    end
  end
end
