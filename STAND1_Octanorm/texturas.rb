# encoding: UTF-8
# =============================================================================
# STAND1 Octanorm — texturas.rb
# Aba "Texturas" da Biblioteca Stand1: so as NAPAS da biblioteca de materiais do
# Hugo (Arqloads), pasta "NAPAS". A ideia e a equipe inteira usar as mesmas napas,
# carregadas do .skm original (cada .skm ja traz os mapas certos do material).
#
# Parte pura (sem SketchUp, testada em tests/test_texturas.rb): descrever, listar,
# resolver, ler_do_zip. Parte do SketchUp: pasta, miniatura, aplicar.
# =============================================================================
require 'zlib'
require 'base64'

module STAND1
  module Octanorm
    module Texturas
      CHAVE = "STAND1_Octanorm".freeze
      ATRIB = "stand1_octanorm_napa".freeze
      PASTA_HUGO = 'C:\ARQLOADS - MATERIAIS PBR PARA SKETCHUP'.freeze
      SUBPASTA = "NAPAS".freeze
      NAPA = /\ANAPA\s/i.freeze # so entra o que e napa de verdade, mesmo que alguem ponha outra coisa na pasta

      def self.padrao
        File.join(PASTA_HUGO, SUBPASTA)
      end

      # Pasta escolhida nesta maquina (Trocar pasta) ou a do Hugo no C:.
      def self.pasta
        p = Sketchup.read_default(CHAVE, "pasta_napas", "").to_s
        p = padrao if p.empty? || !File.directory?(p)
        p
      end

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
      def self.dados
        dir = pasta
        unless File.directory?(dir.to_s)
          return { pasta: dir, napas: [],
                   erro: "Pasta das napas nao encontrada. Instale a biblioteca do Hugo (Arqloads) ou clique em Trocar pasta e escolha a pasta NAPAS." }
        end

        napas = listar(dir)
        r = { pasta: dir, napas: napas }
        r[:erro] = "Nenhuma napa nesta pasta. Escolha a pasta NAPAS da biblioteca do Hugo." if napas.empty?
        r
      rescue StandardError => e
        { pasta: pasta, napas: [], erro: "Erro ao ler as napas: #{e.message}" }
      end

      def self.miniatura(arquivo)
        c = resolver(pasta, arquivo)
        png = c && ler_do_zip(c)
        png ? "data:image/png;base64,#{Base64.strict_encode64(png)}" : nil
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

      # Carrega a napa uma vez por modelo (o .skm traz os mapas). Se ja foi carregada por aqui, reusa.
      def self.carregar(model, caminho)
        chave = normalizar(caminho)
        ja = model.materials.find { |m| m.get_attribute(ATRIB, "origem").to_s == chave }
        return ja if ja

        m = model.materials.load(caminho)
        m.set_attribute(ATRIB, "origem", chave) if m
        m
      end

      # Pinta a selecao: face -> a face; grupo/componente -> o proprio. Sem selecao, a napa
      # vira o material do balde de tinta. { ok:, msg: }
      def self.aplicar(arquivo)
        model = Sketchup.active_model
        caminho = resolver(pasta, arquivo)
        return { ok: false, msg: "Napa nao encontrada na pasta: #{arquivo}" } unless caminho

        model.start_operation("STAND1: aplicar napa", true)
        begin
          m = carregar(model, caminho)
          unless m
            model.abort_operation
            return { ok: false, msg: "O SketchUp nao carregou a napa." }
          end
          alvos = model.selection.select { |e| e.is_a?(Sketchup::Face) || e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
          alvos.each { |e| e.material = m }
          model.materials.current = m if alvos.empty?
          model.commit_operation
        rescue StandardError => e
          model.abort_operation
          return { ok: false, msg: "Nao foi possivel aplicar a napa: #{e.message}" }
        end
        if alvos.empty?
          { ok: true, msg: "#{m.display_name} pronta no balde de tinta (tecla B). Nada estava selecionado." }
        else
          { ok: true, msg: "#{m.display_name} aplicada em #{alvos.size} item(ns)." }
        end
      end
    end
  end
end
