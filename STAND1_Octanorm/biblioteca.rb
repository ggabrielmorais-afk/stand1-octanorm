# encoding: UTF-8
# =============================================================================
# STAND1 Octanorm — biblioteca.rb
# Janela "Biblioteca Stand1": os blocos de CATALOGO STAND1 com miniatura,
# categoria e busca. Um clique poe o bloco na mao pra posicionar (ja vem com a
# tag do Memorial dentro dele).
#
# Le CATALOGO STAND1\catalogo.json (gerado por stand1-catalogo\gerar_indice.py).
# Bloco que esta na pasta mas fora do indice aparece em "Outros", sem miniatura.
#
# "+ Adicionar bloco": salva o grupo/componente selecionado como bloco novo na
# pasta do catalogo (um componente na tag do Memorial, origem no canto
# frente-esquerda-chao), com miniatura. Cada pessoa grava num arquivo proprio
# "meus_blocos_<nome>.json" (nunca no mesmo arquivo que outra pessoa escreve),
# pra duas pessoas adicionando bloco ao mesmo tempo numa pasta compartilhada
# (Drive) nao brigarem pela mesma gravacao. dados() le todos e junta.
#
# Novidades: ao abrir o SketchUp, verificar_novidades avisa quem adicionou o
# que desde a ultima vez que esta maquina checou (popup simples).
# =============================================================================
require 'json'
require 'base64'
require 'fileutils'

module STAND1
  module Octanorm
    module Biblioteca
      CHAVE = "STAND1_Octanorm".freeze
      PADRAO = "C:/Users/User/Documents/GABRIEL EMPRESA/Gabriel Stand 1/CATALOGO STAND1".freeze

      def self.pasta
        p = Sketchup.read_default(CHAVE, "pasta_catalogo", "").to_s
        p = PADRAO if (p.empty? || !File.directory?(p)) && File.directory?(PADRAO)
        p
      end

      def self.abrir
        if @dlg && @dlg.visible?
          @dlg.bring_to_front
          return
        end
        @dlg = UI::HtmlDialog.new(dialog_title: "Biblioteca Stand1", preferences_key: "STAND1_Octanorm_biblioteca",
                                  width: 760, height: 680, min_width: 420, min_height: 360,
                                  style: UI::HtmlDialog::STYLE_DIALOG)
        @dlg.set_file(File.join(__dir__, "html", "biblioteca.html"))
        @dlg.add_action_callback("pronto") { |_c| enviar }
        @dlg.add_action_callback("inserir") { |_c, arq| inserir(arq.to_s) }
        @dlg.add_action_callback("escolher_pasta") { |_c| escolher_pasta }
        @dlg.add_action_callback("abrir_pasta") { |_c| UI.openURL("file:///#{pasta}") unless pasta.empty? }
        @dlg.add_action_callback("preparar_adicionar") { |_c| responder("abrir_form", preparar_adicionar) }
        @dlg.add_action_callback("adicionar") do |_c, json|
          r = adicionar(JSON.parse(json.to_s))
          responder("adicionado", r)
          enviar if r[:ok]
        end
        @dlg.show
      end

      def self.responder(funcao, dados)
        @dlg.execute_script("#{funcao}(#{JSON.generate(dados)})") if @dlg
      end

      SECOES = ["MOBILIÁRIO", "EQUIPAMENTOS", "ELÉTRICA", "ESTRUTURAS", "REVESTIMENTOS", "COMUNICAÇÃO VISUAL"].freeze
      MEUS_GLOB = "meus_blocos*.json".freeze # cobre o antigo meus_blocos.json e o novo meus_blocos_<nome>.json
      MEUS_PREFIXO = "meus_blocos_".freeze

      def self.nome_pessoa
        Sketchup.read_default(CHAVE, "nome_pessoa", "").to_s
      end

      def self.selecionado(model)
        sel = model.selection.to_a
        return nil unless sel.size == 1

        e = sel.first
        e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) ? e : nil
      end

      # O que a janela precisa pra abrir o formulario: nome sugerido e medida.
      def self.preparar_adicionar
        e = selecionado(Sketchup.active_model)
        return { erro: "Selecione UM grupo ou componente no modelo e clique de novo em + Adicionar bloco." } unless e

        b = e.bounds
        nome = e.name.to_s.empty? ? e.definition.name : e.name
        nome = "" if nome =~ /\A(Grupo|Group|Componente|Component)#?\d*\z/i
        { nome: nome.sub(/#\d+\z/, ""), x: b.width.to_cm.round(1), y: b.height.to_cm.round(1), z: b.depth.to_cm.round(1),
          girar: b.height > b.width * 1.05, secoes: SECOES, autor: nome_pessoa }
      end

      def self.nome_de_arquivo(nome)
        nome.to_s.gsub(/[\\\/:*?"<>|#]/, "-").gsub(/\s+/, " ").strip
      end

      ACENTOS = { "á" => "a", "à" => "a", "â" => "a", "ã" => "a", "ä" => "a", "é" => "e", "è" => "e", "ê" => "e",
                 "ë" => "e", "í" => "i", "ì" => "i", "î" => "i", "ï" => "i", "ó" => "o", "ò" => "o", "ô" => "o",
                 "õ" => "o", "ö" => "o", "ú" => "u", "ù" => "u", "û" => "u", "ü" => "u", "ç" => "c", "ñ" => "n" }.freeze

      # Timestamp com milissegundo: ultima_visita_blocos e adicionado_em usam o
      # mesmo formato, comparados como texto em novidades(). So segundo seria
      # fraco demais (duas gravacoes no mesmo segundo colidiriam, perdendo aviso).
      def self.agora
        Time.now.strftime("%Y-%m-%dT%H:%M:%S.%L")
      end

      # "João Silva" -> "joao_silva". Usado so pro NOME DO ARQUIVO de cada
      # pessoa (meus_blocos_<slug>.json), nunca mostrado na tela.
      def self.slug(texto)
        s = texto.to_s.strip.downcase.chars.map { |c| ACENTOS[c] || c }.join
        s = s.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
        s.empty? ? "pessoa" : s
      end

      # dados: { "nome", "secao", "categoria", "girar", "autor" }
      def self.adicionar(dados)
        model = Sketchup.active_model
        e = selecionado(model)
        return { ok: false, erro: "Selecione UM grupo ou componente no modelo." } unless e

        dir = pasta
        return { ok: false, erro: "Pasta do catalogo nao encontrada. Clique em Trocar pasta." } unless File.directory?(dir.to_s)

        nome = nome_de_arquivo(dados["nome"])
        secao = SECOES.include?(dados["secao"]) ? dados["secao"] : nil
        categoria = dados["categoria"].to_s.strip
        autor = dados["autor"].to_s.strip
        return { ok: false, erro: "Falta o nome do bloco." } if nome.empty?
        return { ok: false, erro: "Escolha a secao do Memorial." } unless secao
        return { ok: false, erro: "Escolha ou digite a categoria." } if categoria.empty?
        return { ok: false, erro: "Falta seu nome (aparece pros colegas quando voce adiciona um bloco)." } if autor.empty?

        arq = "#{nome}.skp"
        caminho = File.join(dir, arq)
        return { ok: false, erro: "Ja existe \"#{arq}\" no catalogo. Troque o nome (ex.: com a medida ou a cor)." } if File.exist?(caminho)

        mini_rel = "_previas/mini/#{nome}.png"
        mini = File.join(dir, mini_rel)
        medida = nil
        model.start_operation("STAND1: adicionar bloco", true)
        begin
          # sem a posicao no modelo: mantem giro e escala da selecao
          base = Geom::Transformation.translation(ORIGIN - e.transformation.origin) * e.transformation
          base = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees) * base if dados["girar"]
          comp = model.definitions.add(nome)
          dentro = comp.entities.add_instance(e.definition, base)
          bb = dentro.bounds
          dentro.transform!(Geom::Transformation.translation(Geom::Vector3d.new(-bb.min.x, -bb.min.y, -bb.min.z)))
          arquivo = model.definitions.add("STAND1 bloco temporario")
          principal = arquivo.entities.add_instance(comp, Geom::Transformation.new)
          principal.layer = model.layers[secao] || model.layers.add(secao)
          b = principal.bounds
          medida = [b.width, b.height, b.depth].map { |v| Contagem.cm_txt(v.to_cm) }.join(" x ") + " cm"
          raise "o SketchUp nao salvou o arquivo" unless arquivo.save_as(caminho) && File.exist?(caminho)

          begin # miniatura e bonus: sem ela o bloco aparece "sem imagem"
            FileUtils.mkdir_p(File.dirname(mini))
            comp.refresh_thumbnail
            comp.save_thumbnail(mini)
          rescue StandardError
            nil
          end
        rescue StandardError => err
          model.abort_operation
          return { ok: false, erro: "Nao foi possivel salvar o bloco: #{err.message}" }
        end
        model.abort_operation # desfaz o que foi criado so pra salvar: o modelo fica como estava

        # cada pessoa so grava no PROPRIO arquivo: duas pessoas adicionando bloco
        # ao mesmo tempo numa pasta do Drive nao disputam a mesma gravacao
        arquivo_meu = File.join(dir, "#{MEUS_PREFIXO}#{slug(autor)}.json")
        meus = File.exist?(arquivo_meu) ? (JSON.parse(File.read(arquivo_meu, encoding: "UTF-8"))["blocos"] rescue []) : []
        meus << { "arquivo" => arq, "nome" => nome, "secao" => secao, "categoria" => categoria, "medida" => medida,
                  "mini" => (File.exist?(mini) ? mini_rel : nil), "adicionado_por" => autor,
                  "adicionado_em" => agora, "data" => Time.now.strftime("%d/%m/%Y") }
        File.write(arquivo_meu, JSON.pretty_generate("versao" => 1, "blocos" => meus), encoding: "UTF-8")
        Sketchup.write_default(CHAVE, "nome_pessoa", autor) # lembra pra proxima vez
        { ok: true, nome: nome, arquivo: arq }
      rescue StandardError => err
        { ok: false, erro: "Erro: #{err.message}" }
      end

      # Junta os blocos adicionados por TODO MUNDO: um arquivo por pessoa
      # (meus_blocos_<nome>.json), mais o antigo meus_blocos.json de antes
      # dessa mudanca (o glob pega os dois formatos).
      def self.ler_meus(dir)
        Dir.glob(File.join(dir, MEUS_GLOB)).flat_map do |f|
          JSON.parse(File.read(f, encoding: "UTF-8"))["blocos"] rescue []
        end
      end

      # Entradas adicionadas por OUTRA pessoa depois de "desde" (nil = 1a vez
      # nesta maquina: nao avisa nada, so estabelece a base). Pura, sem
      # SketchUp: testada em tests/test_biblioteca.rb.
      def self.novidades(entradas, desde, meu_nome)
        return [] if desde.nil?

        entradas.select { |b| b["adicionado_em"].to_s > desde.to_s && b["adicionado_por"].to_s != meu_nome.to_s }
                .sort_by { |b| b["adicionado_em"].to_s }
      end

      MAX_AVISO = 8

      # Roda ao abrir o SketchUp: avisa o que a equipe adicionou desde a
      # ultima vez que ESTA maquina checou. So leitura, nunca trava o SketchUp.
      def self.verificar_novidades
        dir = pasta
        return unless File.directory?(dir.to_s)

        desde = Sketchup.read_default(CHAVE, "ultima_visita_blocos", nil)
        novas = novidades(ler_meus(dir), desde, nome_pessoa)
        Sketchup.write_default(CHAVE, "ultima_visita_blocos", agora)
        return if novas.empty?

        linhas = novas.first(MAX_AVISO).map { |b| "• #{b['adicionado_por']} adicionou \"#{b['nome']}\" em #{b['categoria']}" }
        texto = "Blocos novos na Biblioteca Stand1:\n\n#{linhas.join("\n")}"
        texto << "\n\n... e mais #{novas.size - MAX_AVISO} bloco(s)." if novas.size > MAX_AVISO
        UI.messagebox(texto)
      rescue StandardError
        nil # nunca atrapalha a abertura do SketchUp por isso
      end

      def self.escolher_pasta
        p = UI.select_directory(title: "Pasta do catalogo Stand1", directory: pasta)
        return unless p

        Sketchup.write_default(CHAVE, "pasta_catalogo", p.tr("\\", "/"))
        enviar
      end

      # Miniatura como data URL (o HtmlDialog nao carrega file:// de outra pasta
      # de forma confiavel; o EVA passou pelo mesmo problema).
      def self.data_url(caminho)
        return nil unless caminho && File.exist?(caminho)

        tipo = caminho.downcase.end_with?(".png") ? "png" : "jpeg"
        "data:image/#{tipo};base64,#{Base64.strict_encode64(File.binread(caminho))}"
      rescue StandardError
        nil
      end

      def self.dados
        dir = pasta
        return { erro: "Pasta do catalogo nao encontrada. Clique em Trocar pasta.", pasta: dir, blocos: [] } \
          if dir.empty? || !File.directory?(dir)

        indice = {}
        arq_indice = File.join(dir, "catalogo.json")
        if File.exist?(arq_indice)
          JSON.parse(File.read(arq_indice, encoding: "UTF-8"))["blocos"].each { |b| indice[b["arquivo"]] = b }
        end
        meu_nome = nome_pessoa
        ler_meus(dir).each { |b| indice[b["arquivo"]] ||= b.merge("meu" => (b["adicionado_por"].to_s == meu_nome && !meu_nome.empty?)) }

        # .skp da raiz + os do indice que ficam em subpasta (ex.: STANDS PRONTOS/...)
        arquivos = Dir.children(dir).select { |f| f.downcase.end_with?(".skp") }
        arquivos += indice.keys.select { |a| a.include?("/") && File.exist?(File.join(dir, a)) }
        blocos = arquivos.uniq.sort.map do |arq|
          b = indice[arq] || { "arquivo" => arq, "nome" => File.basename(arq, ".skp"), "categoria" => "Outros",
                               "secao" => "", "medida" => "" }
          mini = b["mini"] ? File.join(dir, b["mini"]) : nil
          b.merge("img" => data_url(mini))
        end
        { pasta: dir, blocos: blocos, sem_indice: !File.exist?(arq_indice) }
      rescue StandardError => e
        { erro: "Erro ao ler o catalogo: #{e.message}", pasta: pasta, blocos: [] }
      end

      def self.enviar
        return unless @dlg

        @dlg.execute_script("carregar(#{JSON.generate(dados)})")
      end

      def self.inserir(arq)
        # so arquivo de dentro da pasta do catalogo (aceita subpasta, nunca "..")
        rel = arq.tr("\\", "/").split("/").reject { |p| p.empty? || p == "." || p == ".." }.join("/")
        caminho = File.join(pasta, rel)
        unless File.exist?(caminho)
          UI.messagebox("Bloco nao encontrado:\n#{caminho}")
          return
        end
        model = Sketchup.active_model
        defn = model.definitions.load(caminho)
        model.place_component(defn, false)
      rescue StandardError => e
        UI.messagebox("Nao foi possivel inserir o bloco:\n#{e.message}")
      end
    end
  end
end
