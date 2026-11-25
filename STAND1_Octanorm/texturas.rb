# encoding: UTF-8
# =============================================================================
# STAND1 Octanorm — texturas.rb
# Aba "Texturas" da Biblioteca Stand1. Duas categorias, com o nome exato do padrao da Stand1:
#
#   Napa              as napas da biblioteca de materiais do Hugo (Arqloads), pasta "NAPAS".
#                     Carregadas do .skm original, que ja traz os mapas certos do material.
#                     A pasta e achada sozinha: a escolhida em Trocar pasta, a do Hugo no C: ou a
#                     NAPAS ao lado do catalogo da Biblioteca (os .skm nao vao dentro do plugin).
#   Forracao carpete  as 20 cores da "Forracao com resina" (amostras do fornecedor), que vem
#                     junto do plugin em materiais/forracao_carpete. O material sai com o nome
#                     "Forracao carpete <cor>", do jeito que o Memorial le (convencao de 26/10).
#
# A ideia e a equipe inteira usar o mesmo material. Parte pura (sem SketchUp, testada em
# tests/test_texturas.rb): descrever, listar, resolver, ler_do_zip, carpetes. Parte do
# SketchUp: pasta, dados, miniatura, aplicar.
# =============================================================================
require 'json'
require 'zlib'
require 'base64'

module STAND1
  module Octanorm
    module Texturas
      CHAVE = "STAND1_Octanorm".freeze
      ATRIB = "stand1_octanorm_textura".freeze
      CAT_NAPA = "Napa".freeze
      CAT_CARPETE = "Forração carpete".freeze
      PASTA_HUGO = 'C:\ARQLOADS - MATERIAIS PBR PARA SKETCHUP'.freeze
      SUBPASTA = "NAPAS".freeze
      NAPA = /\ANAPA\s/i.freeze # so entra o que e napa de verdade, mesmo que alguem ponha outra coisa na pasta
      CARPETE_DIR = File.join(__dir__, "materiais", "forracao_carpete").freeze
      TAMANHO_PADRAO_M = 0.5 # lado real, em metros, de cada repeticao da textura de carpete

      def self.padrao
        File.join(PASTA_HUGO, SUBPASTA)
      end

      # Onde procurar as napas, em ordem: a pasta escolhida em Trocar pasta, a do Hugo no C: e a
      # pasta NAPAS ao lado do catalogo da Biblioteca (quem copia as napas pro Drive da equipe
      # nao precisa clicar em nada).
      def self.candidatas(escolhida, catalogo)
        lista = []
        lista << escolhida.to_s unless escolhida.to_s.empty?
        lista << padrao
        lista << File.join(catalogo.to_s, SUBPASTA) unless catalogo.to_s.empty?
        lista.uniq
      end

      # A primeira candidata que tem napa. Se nenhuma tem, a primeira que e pasta (a aba avisa
      # que esta vazia); se nenhuma existe, a escolhida ou a do Hugo, so pro aviso de pasta nao achada.
      def self.escolher(candidatas)
        candidatas.find { |d| !listar(d).empty? } ||
          candidatas.find { |d| File.directory?(d) } ||
          candidatas.first
      end

      def self.catalogo
        Biblioteca.pasta.to_s
      rescue StandardError # NameError (Biblioteca ainda nao carregada, como nos testes puros) tambem cai aqui
        ""
      end

      # Pasta das napas nesta maquina (ver candidatas).
      def self.pasta
        escolher(candidatas(Sketchup.read_default(CHAVE, "pasta_napas", ""), catalogo))
      end

      # ---- napas ----------------------------------------------------------------------
      # "NAPA 37324 BRANCO - MSKP.skm" -> { arquivo:, nome: "NAPA 37324 BRANCO", codigo: "37324", cor: "BRANCO" }
      def self.descrever(arquivo)
        base = File.basename(arquivo.to_s, ".*").sub(/\s*-\s*MSKP\s*\z/i, "").strip
        m = base.match(/\ANAPA\s+(\d+)\s+(.+)\z/i)
        { arquivo: File.basename(arquivo.to_s), nome: base, codigo: m ? m[1] : "", cor: m ? m[2].strip : base }
      end

      # Napas da pasta (so os .skm da raiz que comecam com "NAPA "), por cor.
      def self.listar(dir)
        return [] unless dir && File.directory?(dir)

        Dir.children(dir).select { |f| f =~ /\.skm\z/i && f =~ NAPA }
           .map { |f| descrever(f) }.sort_by { |n| [n[:cor].downcase, n[:codigo]] }
      end

      # Caminho de um .skm da pasta: so o nome do arquivo, nunca subpasta nem "..".
      def self.resolver(dir, arquivo)
        nome = File.basename(arquivo.to_s.tr("\\", "/"))
        return nil if nome.empty? || nome == "." || nome == ".." || nome !~ /\.skm\z/i || nome !~ NAPA

        caminho = File.join(dir.to_s, nome)
        File.exist?(caminho) ? caminho : nil
      end

      # ---- forracao carpete -------------------------------------------------------------
      def self.nome_carpete(cor)
        "Forração carpete #{cor.to_s.strip}"
      end

      def self.manifesto(dir = CARPETE_DIR)
        JSON.parse(File.read(File.join(dir, "carpetes.json"), encoding: "UTF-8"))
      rescue StandardError
        { "itens" => [] }
      end

      # [{ arquivo:, cor:, nome: "Forração carpete preto" }] so do que tem o .jpg na pasta
      def self.carpetes(dir = CARPETE_DIR)
        manifesto(dir)["itens"].select { |i| File.exist?(File.join(dir, i["arquivo"].to_s)) }.map do |i|
          { arquivo: i["arquivo"], cor: i["cor"], nome: nome_carpete(i["cor"]) }
        end
      end

      def self.tamanho_carpete(dir = CARPETE_DIR)
        t = manifesto(dir)["tamanho_m"].to_f
        t > 0 ? t : TAMANHO_PADRAO_M
      end

      # Caminho do .jpg de um item do manifesto (so o nome do arquivo; "mini" = miniatura).
      def self.resolver_carpete(arquivo, dir = CARPETE_DIR, mini = false)
        nome = File.basename(arquivo.to_s.tr("\\", "/"))
        return nil unless carpetes(dir).any? { |c| c[:arquivo] == nome }

        caminho = mini ? File.join(dir, "mini", nome) : File.join(dir, nome)
        File.exist?(caminho) ? caminho : nil
      end

      # ---- ids da janela: "napa:<arquivo>" e "carpete:<arquivo>" ---------------------------
      def self.separar_id(id)
        tipo, arq = id.to_s.split(":", 2)
        [tipo.to_s, arq.to_s]
      end

      # ---- miniatura de dentro do .skm (e um zip com doc_thumbnail.png) ----------
      # Le so o arquivo pedido: acha o diretorio central pelo fim do zip, depois o
      # cabecalho local. Metodos 0 (guardado) e 8 (deflate). nil se nao achar.
      def self.ler_do_zip(caminho, nome = "doc_thumbnail.png")
        File.open(caminho, "rb") do |f|
          tam = f.size
          return nil if tam < 22

          janela = [tam, 65_557].min
          f.seek(tam - janela)
          fim = f.read(janela)
          pos = fim.rindex("PK\x05\x06".b)
          return nil unless pos

          n, cd_tam, cd_ini = fim[pos + 10, 12].unpack("vVV")
          f.seek(cd_ini)
          cd = f.read(cd_tam)
          i = 0
          n.times do
            break unless cd[i, 4] == "PK\x01\x02".b

            metodo, = cd[i + 10, 2].unpack("v")
            comp, = cd[i + 20, 4].unpack("V")
            ln, le, lc = cd[i + 28, 6].unpack("vvv")
            local, = cd[i + 42, 4].unpack("V")
            arq = cd[i + 46, ln].force_encoding("UTF-8")
            if arq == nome
              f.seek(local)
              cab = f.read(30)
              return nil unless cab[0, 4] == "PK\x03\x04".b

              lnl, lel = cab[26, 4].unpack("vv")
              f.seek(local + 30 + lnl + lel)
              dados = f.read(comp)
              return dados if metodo == 0
              return Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(dados) if metodo == 8

              return nil
            end
            i += 46 + ln + le + lc
          end
        end
        nil
      rescue StandardError
        nil
      end

      # ---- o que a janela recebe ---------------------------------------------------
      # itens: [{ id:, categoria:, nome:, cor:, codigo:, arquivo: }]. O erro (se houver) e so das napas:
      # sem a biblioteca do Hugo a aba ainda mostra a forracao carpete.
      def self.dados
        dir = pasta
        itens = carpetes.map { |c| c.merge(id: "carpete:#{c[:arquivo]}", categoria: CAT_CARPETE, codigo: "") }
        r = { pasta: dir, itens: itens }
        if File.directory?(dir.to_s)
          napas = listar(dir).map { |n| n.merge(id: "napa:#{n[:arquivo]}", categoria: CAT_NAPA) }
          r[:itens] = napas + itens
          r[:erro] = "Nenhuma napa nesta pasta. Escolha a pasta NAPAS da biblioteca do Hugo." if napas.empty?
        else
          r[:erro] = "Pasta das napas nao encontrada. Ponha a pasta NAPAS ao lado do catalogo da Biblioteca, instale a biblioteca do Hugo (Arqloads) ou clique em Trocar pasta e escolha a pasta NAPAS. A forracao carpete funciona sem ela."
        end
        r
      rescue StandardError => e
        { pasta: pasta, itens: [], erro: "Erro ao ler as texturas: #{e.message}" }
      end

      def self.miniatura(id)
        tipo, arq = separar_id(id)
        if tipo == "napa"
          c = resolver(pasta, arq)
          png = c && ler_do_zip(c)
          png ? "data:image/png;base64,#{Base64.strict_encode64(png)}" : nil
        elsif tipo == "carpete"
          c = resolver_carpete(arq, CARPETE_DIR, true)
          c ? "data:image/jpeg;base64,#{Base64.strict_encode64(File.binread(c))}" : nil
        end
      rescue StandardError
        nil
      end

      def self.escolher_pasta
        p = UI.select_directory(title: "Pasta NAPAS da biblioteca do Hugo (.skm)", directory: pasta)
        return false unless p

        Sketchup.write_default(CHAVE, "pasta_napas", p.tr("\\", "/"))
        true
      end

      # ---- aplicar --------------------------------------------------------------------
      def self.normalizar(caminho)
        caminho.to_s.tr("\\", "/").downcase
      end

      # Napa: carrega uma vez por modelo (o .skm traz os mapas). Reusa a que ja foi carregada por aqui ou a que a
      # pessoa ja trouxe pelo painel de materiais do SketchUp (mesmo nome do .skm e com textura): sem isso o
      # SketchUp criaria uma copia "NAPA ... BRANCO1".
      def self.carregar_napa(model, caminho)
        chave = normalizar(caminho)
        ja = model.materials.find { |m| m.get_attribute(ATRIB, "origem").to_s == chave }
        return ja if ja

        igual = model.materials[descrever(caminho)[:nome]]
        if igual && igual.texture
          igual.set_attribute(ATRIB, "origem", chave)
          return igual
        end

        m = model.materials.load(caminho)
        m.set_attribute(ATRIB, "origem", chave) if m
        m
      end

      # Carpete: material com o nome exato do padrao, textura do .jpg do plugin no tamanho real.
      # Se o modelo ja tem um material com esse nome que nao veio daqui, nao mexe nele: cria outro
      # (o SketchUp acrescenta "#1") e o aviso conta isso.
      def self.carregar_carpete(model, item, caminho)
        chave = "carpete:#{item[:arquivo]}"
        ja = model.materials.find { |m| m.get_attribute(ATRIB, "origem").to_s == chave }
        return [ja, nil] if ja

        outro = model.materials[item[:nome]]
        m = model.materials.add(item[:nome])
        m.texture = caminho
        m.texture.size = tamanho_carpete.m if m.texture
        m.set_attribute(ATRIB, "origem", chave)
        aviso = outro ? "Ja existia um material chamado \"#{item[:nome]}\" no modelo; este saiu como \"#{m.name}\"." : nil
        [m, aviso]
      end

      def self.pintar(model, m)
        alvos = model.selection.select { |e| e.is_a?(Sketchup::Face) || e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
        alvos.each { |e| e.material = m }
        model.materials.current = m if alvos.empty?
        alvos.size
      end

      # Pinta a selecao: face -> a face; grupo/componente -> o proprio. Sem selecao, o material
      # vira o do balde de tinta. { ok:, msg: }
      def self.aplicar(id)
        model = Sketchup.active_model
        tipo, arq = separar_id(id)
        if tipo == "napa"
          caminho = resolver(pasta, arq)
          return { ok: false, msg: "Napa nao encontrada na pasta: #{arq}" } unless caminho
        elsif tipo == "carpete"
          item = carpetes.find { |c| c[:arquivo] == File.basename(arq) }
          caminho = item && resolver_carpete(arq)
          return { ok: false, msg: "Forracao carpete nao encontrada no plugin: #{arq}" } unless caminho
        else
          return { ok: false, msg: "Textura desconhecida: #{id}" }
        end

        model.start_operation("STAND1: aplicar textura", true)
        begin
          aviso = nil
          if tipo == "napa"
            m = carregar_napa(model, caminho)
          else
            m, aviso = carregar_carpete(model, item, caminho)
          end
          unless m
            model.abort_operation
            return { ok: false, msg: "O SketchUp nao carregou a textura." }
          end
          n = pintar(model, m)
          model.commit_operation
        rescue StandardError => e
          model.abort_operation
          return { ok: false, msg: "Nao foi possivel aplicar a textura: #{e.message}" }
        end
        msg = n.zero? ? "#{m.display_name} pronta no balde de tinta (tecla B). Nada estava selecionado." : "#{m.display_name} aplicada em #{n} item(ns)."
        { ok: true, msg: [msg, aviso].compact.join(" ") }
      end
    end
  end
end
