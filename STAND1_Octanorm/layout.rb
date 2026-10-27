# encoding: UTF-8
# =============================================================================
# STAND1 Octanorm — layout.rb
# Calculo puro (sem SketchUp): divide um caminho em trechos e cada trecho em
# folhas de Octanorm. Testavel com Ruby comum: ruby tests/test_layout.rb
# Unidades: centimetros.
# =============================================================================

module STAND1
  module Octanorm
    module Layout
      MODULO   = 100.0 # eixo a eixo
      PERFIL   = 4.0   # montante 4 x 4 cm
      MINIMO   = 5.0   # sobra menor que isso nao vira folha (vira aviso)
      EPS      = 0.01

      # Divide um trecho reto de `comprimento` cm em folhas.
      # Devolve { folhas: [{ x:, largura:, especial: }], sobra:, aviso: }
      #   x       = inicio da folha (eixo do montante anterior), em cm
      #   largura = eixo a eixo (100 nas folhas normais)
      MEIO = 50.0          # folha TS de 0,50 e vidro de 0,49 (meio modulo)
      MEIO_TOLERANCIA = 5.0

      # sobra de ~50 cm vira meio modulo (TS e vidro tem peca de 0,50), nao folha especial
      def self.folhas(comprimento, modulo = MODULO, meio: true)
        raise ArgumentError, "comprimento invalido" unless comprimento.to_f > 0

        comprimento = comprimento.to_f
        n = (comprimento / modulo + EPS).floor
        resto = (comprimento - n * modulo).round(2)
        lista = Array.new(n) { |i| { x: (i * modulo).round(2), largura: modulo, especial: false } }
        aviso = nil
        if meio && (resto - MEIO).abs <= MEIO_TOLERANCIA
          lista << { x: (n * modulo).round(2), largura: resto, especial: false, meio: true }
        elsif resto >= MINIMO
          lista << { x: (n * modulo).round(2), largura: resto, especial: true }
        elsif resto > EPS
          aviso = "sobra de #{fmt(resto)} cm sem folha (menor que #{fmt(MINIMO)} cm)"
        end
        { folhas: lista, sobra: (resto < MINIMO ? resto : 0.0), aviso: aviso }
      end

      # Divide uma lista de pontos [[x,y], ...] em trechos retos.
      # fechado = true liga o ultimo ponto ao primeiro (sala).
      # Cada trecho sabe se poe montante no inicio: num canto, o montante e do
      # trecho anterior (nao duplica perfil na esquina).
      # compartilhados: pontos que ja tem montante de outra parede (a parede nova
      # encostou num montante existente) -> nao poe outro montante ali.
      def self.trechos(pontos, fechado = false, compartilhados = [])
        pts = pontos.map { |p| [p[0].to_f, p[1].to_f] }
        pts = remover_repetidos(pts)
        raise ArgumentError, "precisa de pelo menos 2 pontos" if pts.size < 2

        ja_tem = ->(p) { compartilhados.any? { |c| dist(c, p) < 1.0 } }
        pares = pts.each_cons(2).to_a
        pares << [pts.last, pts.first] if fechado && pts.size >= 3
        pares.each_with_index.map do |(a, b), i|
          dx = b[0] - a[0]
          dy = b[1] - a[1]
          {
            inicio: a,
            fim: b,
            comprimento: Math.sqrt(dx * dx + dy * dy).round(2),
            angulo: Math.atan2(dy, dx),
            montante_inicio: !(i > 0 || (fechado && pts.size >= 3)) && !ja_tem.call(a),
            montante_fim: !ja_tem.call(b)
          }
        end
      end

      # Onde ficam os montantes de uma parede (cm, mesmo sistema dos pontos).
      # A ferramenta usa como "ima": a parede nova encosta e fecha nesses pontos.
      def self.eixos(trechos, meio: true)
        lista = []
        trechos.each do |t|
          ax, ay = t[:inicio]
          bx, by = t[:fim]
          c = t[:comprimento]
          next if c <= 0

          ([0.0] + folhas(c, meio: meio)[:folhas].map { |f| f[:x] + f[:largura] }).each do |d|
            u = d / c
            p = [(ax + u * (bx - ax)).round(2), (ay + u * (by - ay)).round(2)]
            lista << p unless lista.any? { |q| dist(q, p) < 1.0 }
          end
        end
        lista
      end

      # Resumo pra o relatorio: total de folhas normais, especiais, m2.
      def self.resumo(trechos, altura, meio: true)
        normais = especiais = meios = 0
        m2 = 0.0
        avisos = []
        trechos.each_with_index do |t, i|
          r = folhas(t[:comprimento], meio: meio)
          normais   += r[:folhas].count { |f| !f[:especial] && !f[:meio] }
          meios     += r[:folhas].count { |f| f[:meio] }
          especiais += r[:folhas].count { |f| f[:especial] }
          m2 += t[:comprimento] * altura / 10_000.0
          avisos << "trecho #{i + 1}: #{r[:aviso]}" if r[:aviso]
          r[:folhas].select { |f| f[:especial] }.each do |f|
            avisos << "trecho #{i + 1}: folha especial de #{fmt(f[:largura])} cm"
          end
        end
        { folhas_normais: normais, folhas_meio: meios, folhas_especiais: especiais, m2: m2.round(2), avisos: avisos }
      end

      # Porta por padrao: ultimo vao de 1,00 m do ultimo trecho (de tras pra frente).
      # Devolve { trecho:, vao: } ou nil se nenhum vao inteiro existe.
      def self.porta_padrao(trechos, meio: true)
        trechos.each_index.to_a.reverse_each do |ti|
          fs = folhas(trechos[ti][:comprimento], meio: meio)[:folhas]
          vi = fs.rindex { |f| inteiro?(f) }
          return { trecho: ti, vao: vi } if vi
        end
        nil
      end

      # Vao de 1,00 m mais perto de um ponto (cm, mesmo sistema dos trechos).
      # Usado pra "mover porta": clica perto do vao e a porta vai pra la.
      def self.vao_no_ponto(trechos, x, y, meio: true)
        melhor = nil
        trechos.each_with_index do |t, ti|
          ax, ay = t[:inicio]
          bx, by = t[:fim]
          dx = bx - ax
          dy = by - ay
          len2 = dx * dx + dy * dy
          next if len2 <= 0

          u = (((x - ax) * dx + (y - ay) * dy) / len2).clamp(0.0, 1.0)
          d = dist([ax + u * dx, ay + u * dy], [x, y])
          ao_longo = u * t[:comprimento]
          fs = folhas(t[:comprimento], meio: meio)[:folhas]
          vi = fs.index { |f| ao_longo >= f[:x] && ao_longo <= f[:x] + f[:largura] } || fs.size - 1
          next unless inteiro?(fs[vi])

          melhor = { trecho: ti, vao: vi, distancia: d } if melhor.nil? || d < melhor[:distancia]
        end
        melhor && { trecho: melhor[:trecho], vao: melhor[:vao] }
      end

      # Medida digitada na caixa de medida -> cm. Numero sozinho = METROS
      # ("3" = 3,00 m, "2,5" = 2,50 m). Aceita "300cm", "300 cm", "3m", "3,40 m".
      # Devolve nil se nao entender.
      def self.ler_medida(texto)
        t = texto.to_s.strip.downcase.tr(",", ".").delete(" ")
        m = t.match(/\A(\d+(?:\.\d+)?)(cm|mm|m)?\z/)
        return nil unless m

        v = m[1].to_f
        cm = case m[2]
             when "cm" then v
             when "mm" then v / 10.0
             else v * 100.0 # sem unidade ou "m": metros
             end
        cm > 0 ? cm.round(2) : nil
      end

      # Testeira de ilha: montantes que descem ate o chao (sustentam a testeira) sao
      # os de canto e os das pontas. Devolve [[trecho, :inicio|:fim], ...] de quem
      # poe esse montante (o canto e do trecho que chega nele).
      def self.apoios_ate_chao(trechos)
        lista = []
        trechos.each_with_index do |t, i|
          lista << [i, :inicio] if t[:montante_inicio]
          lista << [i, :fim] if t[:montante_fim]
        end
        lista
      end

      # ---- Teto grid Z500 ----------------------------------------------------
      # Linhas da grade (cm) num lado de `comprimento`: 0, 100, 200 ... comprimento.
      # Mesma modulacao das paredes: 1,00 m e meio modulo de 0,50. Sobra menor
      # que 5 cm estica o ultimo modulo (o teto fecha na medida certa).
      def self.grade(comprimento)
        g = [0.0] + folhas(comprimento)[:folhas].map { |f| (f[:x] + f[:largura]).round(2) }
        g[-1] = comprimento.to_f.round(2) if g.size > 1
        g
      end

      # O teto no sistema dele e o retangulo 0..l x 0..p.
      # Lados: 0 = y 0, 1 = x l, 2 = y p, 3 = x 0. Cantos: (0,0) (l,0) (l,p) (0,p).
      def self.cantos_do_teto(l, p)
        [[0.0, 0.0], [l.to_f, 0.0], [l.to_f, p.to_f], [0.0, p.to_f]]
      end

      # Ponto (cm) levado pro sistema do teto (origem no canto, eixo X girado de `angulo`).
      def self.no_teto(pt, origem, angulo)
        dx = pt[0] - origem[0]
        dy = pt[1] - origem[1]
        c = Math.cos(angulo)
        s = Math.sin(angulo)
        [(dx * c + dy * s).round(2), (-dx * s + dy * c).round(2)]
      end

      # Lados do teto que ficam em cima de parede (segmentos [[a, b], ...] no
      # sistema do teto): todo ponto do lado, a cada 25 cm, a menos de `tol` de
      # alguma parede. Ali o teto nao leva viga nem no: o topo da parede fecha a borda.
      def self.lados_cobertos(l, p, segmentos, tol = 2.0)
        c = cantos_do_teto(l, p)
        4.times.map do |i|
          a = c[i]
          b = c[(i + 1) % 4]
          n = [(dist(a, b) / 25.0).ceil, 1].max
          (0..n).all? do |k|
            u = k.to_f / n
            q = [a[0] + u * (b[0] - a[0]), a[1] + u * (b[1] - a[1])]
            segmentos.any? { |s| dist_segmento(q, s[0], s[1]) <= tol }
          end
        end
      end

      # Cantos que nao encostam em parede nenhuma: levam montante ate o chao.
      def self.cantos_soltos(l, p, segmentos, tol = 2.0)
        cantos_do_teto(l, p).reject { |c| segmentos.any? { |s| dist_segmento(c, s[0], s[1]) <= tol } }
      end

      # Vigas [[a, b], ...] e nos [[x, y], ...] do teto (sistema do teto, cm).
      # Lado em cima de parede nao leva viga nem no; canto solto leva montante
      # ate o chao no lugar do no.
      def self.teto_pecas(l, p, lados = [false] * 4, soltos = [])
        gx = grade(l)
        gy = grade(p)
        borda = lambda do |x, y|
          (lados[0] && y.abs < EPS) || (lados[1] && (x - gx.last).abs < EPS) ||
            (lados[2] && (y - gy.last).abs < EPS) || (lados[3] && x.abs < EPS)
        end
        vigas = []
        gy.each do |y|
          next if (lados[0] && y.abs < EPS) || (lados[2] && (y - gy.last).abs < EPS)

          gx.each_cons(2) { |xa, xb| vigas << [[xa, y], [xb, y]] }
        end
        gx.each do |x|
          next if (lados[3] && x.abs < EPS) || (lados[1] && (x - gx.last).abs < EPS)

          gy.each_cons(2) { |ya, yb| vigas << [[x, ya], [x, yb]] }
        end
        nos = gy.flat_map { |y| gx.map { |x| [x, y] } }
        nos.reject! { |x, y| borda.call(x, y) || soltos.any? { |s| dist(s, [x, y]) < 1.0 } }
        { vigas: vigas, nos: nos }
      end

      # Pontas de viga em cima de parede que nao caem num montante (ex.: sala de
      # 4,50 com o meio modulo em pontas diferentes nas paredes opostas).
      def self.pontas_sem_montante(l, p, lados, montantes, tol = 2.0)
        gx = grade(l)
        gy = grade(p)
        pontas = []
        pontas.concat(gx.map { |x| [x, 0.0] }) if lados[0]
        pontas.concat(gy.map { |y| [gx.last, y] }) if lados[1]
        pontas.concat(gx.map { |x| [x, gy.last] }) if lados[2]
        pontas.concat(gy.map { |y| [0.0, y] }) if lados[3]
        pontas.uniq.count { |q| montantes.none? { |m| dist(m, q) <= tol } }
      end

      # Retangulo do teto a partir dos pontos de uma sala (cm). O lado X e o 1o
      # trecho da sala; devolve { origem: [x, y], angulo: rad, l:, p: } com a
      # origem no canto de menor coordenada nesse sistema (teto girado junto
      # com a sala).
      def self.retangulo_da_sala(pontos)
        pts = remover_repetidos(pontos.map { |p| [p[0].to_f, p[1].to_f] })
        raise ArgumentError, "sala precisa de pelo menos 3 pontos" if pts.size < 3

        dx = pts[1][0] - pts[0][0]
        dy = pts[1][1] - pts[0][1]
        n = Math.sqrt(dx * dx + dy * dy)
        u = [dx / n, dy / n]
        v = [-u[1], u[0]]
        pu = pts.map { |p| (p[0] - pts[0][0]) * u[0] + (p[1] - pts[0][1]) * u[1] }
        pv = pts.map { |p| (p[0] - pts[0][0]) * v[0] + (p[1] - pts[0][1]) * v[1] }
        mu = pu.min
        mv = pv.min
        origem = [pts[0][0] + u[0] * mu + v[0] * mv, pts[0][1] + u[1] * mu + v[1] * mv].map { |c| c.round(2) }
        { origem: origem, angulo: Math.atan2(u[1], u[0]), l: (pu.max - mu).round(2), p: (pv.max - mv).round(2) }
      end

      # "3x4", "3 x 4", "3;4", "3,5 x 2" -> [300, 400] (cm). Cada parte segue
      # ler_medida (numero sozinho = metros). nil se nao entender.
      def self.ler_dimensoes(texto)
        partes = texto.to_s.strip.downcase.split(/\s*(?:x|;|\*|\s)\s*/).reject(&:empty?)
        return nil unless partes.size == 2

        a, b = partes.map { |p| ler_medida(p) }
        a && b ? [a, b] : nil
      end

      # ---- Editar ------------------------------------------------------------
      # "3; 2,5; 3" -> [300, 250, 300] (cm). Separador e o ponto e virgula (a
      # virgula e decimal). nil se alguma parte nao for medida.
      def self.ler_lista(texto)
        partes = texto.to_s.split(";").map(&:strip).reject(&:empty?)
        return nil if partes.empty?

        lista = partes.map { |p| ler_medida(p) }
        lista.all? ? lista : nil
      end

      # Sala de 4 cantos em angulo reto: a unica que da pra editar por L x P.
      def self.retangulo?(pontos)
        pts = remover_repetidos(pontos.map { |p| [p[0].to_f, p[1].to_f] })
        pts.pop if pts.size > 1 && dist(pts.first, pts.last) <= EPS
        return false unless pts.size == 4

        4.times.all? do |i|
          a = pts[i]
          b = pts[(i + 1) % 4]
          c = pts[(i + 2) % 4]
          u = [b[0] - a[0], b[1] - a[1]]
          v = [c[0] - b[0], c[1] - b[1]]
          nu = Math.hypot(*u)
          nv = Math.hypot(*v)
          nu > EPS && nv > EPS && ((u[0] * v[0] + u[1] * v[1]) / (nu * nv)).abs < 0.01
        end
      end

      # Sala retangular com nova medida: mesmo 1o canto e mesmas direcoes. O 1o
      # trecho fica com `l`, o 2o com `p`.
      def self.refazer_retangulo(pontos, l, p)
        a, b, c = pontos.first(3).map { |q| [q[0].to_f, q[1].to_f] }
        u = unitario(a, b)
        v = unitario(b, c)
        [a, [a[0] + u[0] * l, a[1] + u[1] * l],
         [a[0] + u[0] * l + v[0] * p, a[1] + u[1] * l + v[1] * p],
         [a[0] + v[0] * p, a[1] + v[1] * p]].map { |q| q.map { |k| k.round(2) } }
      end

      # Parede aberta com novos comprimentos: mesmo ponto inicial e mesmas
      # direcoes, cada trecho com a medida nova.
      def self.refazer_pontos(pontos, comprimentos)
        pts = remover_repetidos(pontos.map { |q| [q[0].to_f, q[1].to_f] })
        raise ArgumentError, "sao #{pts.size - 1} trecho(s), vieram #{comprimentos.size} medida(s)" unless comprimentos.size == pts.size - 1

        novos = [pts[0]]
        pts.each_cons(2).with_index do |(a, b), i|
          u = unitario(a, b)
          o = novos.last
          novos << [(o[0] + u[0] * comprimentos[i]).round(2), (o[1] + u[1] * comprimentos[i]).round(2)]
        end
        novos
      end

      def self.unitario(a, b)
        n = dist(a, b)
        raise ArgumentError, "trecho de comprimento zero" if n < EPS

        [(b[0] - a[0]) / n, (b[1] - a[1]) / n]
      end

      def self.dist_segmento(q, a, b)
        dx = b[0] - a[0]
        dy = b[1] - a[1]
        l2 = dx * dx + dy * dy
        return dist(q, a) if l2 < EPS

        u = (((q[0] - a[0]) * dx + (q[1] - a[1]) * dy) / l2).clamp(0.0, 1.0)
        dist(q, [a[0] + u * dx, a[1] + u * dy])
      end

      # Vidro e MDF vao do lado direito de quem desenha (-Y do trecho). Sala
      # desenhada no sentido horario tem o lado de dentro a direita: ai a parede
      # e espelhada pra placa ficar sempre pra fora. Vale pra sala, ilha e parede
      # em L (o "dentro" do L e o lado do canto). Parede reta (2 pontos) nao muda.
      def self.horario?(pontos)
        pts = remover_repetidos(pontos.map { |p| [p[0].to_f, p[1].to_f] })
        return false if pts.size < 3

        area = 0.0
        pts.each_with_index do |a, i|
          b = pts[(i + 1) % pts.size]
          area += a[0] * b[1] - b[0] * a[1]
        end
        area < -EPS
      end

      # ---- Nomes pro Memorial ------------------------------------------------
      # Sequencia da Stand1: "<Parede | Testeira | ambiente> em perfil de aluminio
      # com fechamento em <TS | vidro | MDF>". A medida nao vai no nome: o
      # Memorial ja mostra.
      FECHAMENTO_NOME = { ts: "TS", vidro: "vidro", mdf: "MDF" }.freeze
      AMBIENTES = { "Sala" => "Sala", "Deposito" => "Depósito", "Copa" => "Copa", "Cabine" => "Cabine" }.freeze

      def self.nome_memorial(tipo, fechamento)
        f = FECHAMENTO_NOME[fechamento.to_sym]
        "#{tipo} em perfil de alumínio " + (f ? "com fechamento em #{f}" : "sem fechamento")
      end

      # Tipo (Sala / Deposito / Copa / Cabine) + complemento -> "Depósito de apoio".
      # O tipo vem primeiro: e a palavra que faz o Memorial medir como recinto.
      def self.nome_ambiente(tipo, complemento = "")
        base = AMBIENTES[tipo.to_s] || AMBIENTES.values.find { |v| v == tipo.to_s } || "Sala"
        [base, complemento.to_s.strip].reject(&:empty?).join(" ")
      end

      # porta so entra em vao de 1,00 m (nem especial, nem meio modulo)
      def self.inteiro?(f)
        !f[:especial] && !f[:meio]
      end

      def self.remover_repetidos(pts)
        pts.each_with_object([]) do |p, acc|
          acc << p if acc.empty? || dist(acc.last, p) > EPS
        end
      end

      def self.dist(a, b)
        Math.sqrt((a[0] - b[0])**2 + (a[1] - b[1])**2)
      end

      # 2,70 / 4,00 — virgula, duas casas, em metros
      def self.metros(cm)
        format("%.2f", cm.to_f / 100.0).tr(".", ",")
      end

      def self.fmt(v)
        v.to_f.round(1).to_s.sub(/\.0\z/, "").tr(".", ",")
      end
    end
  end
end
