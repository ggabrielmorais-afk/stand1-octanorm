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
# frente-esquerda-chao), com miniatura. O indice desses blocos fica em
# meus_blocos.json, separado do catalogo.json: catalogo novo que chegar do
# Gabriel nao apaga os blocos que cada um criou.
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
      MEUS = "meus_blocos.json".freeze

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
          girar: b.height > b.width * 1.05, secoes: SECOES }
      end

      def self.nome_de_arquivo(nome)
        nome.to_s.gsub(/[\\\/:*?"<>|#]/, "-").gsub(/\s+/, " ").strip
      end

      # dados: { "nome", "secao", "categoria", "girar" }
      def self.adicionar(dados)
        model = Sketchup.active_model
        e = selecionado(model)
        return { ok: false, erro: "Selecione UM grupo ou componente no modelo." } unless e

        dir = pasta
        return { ok: false, erro: "Pasta do catalogo nao encontrada. Clique em Trocar pasta." } unless File.directory?(dir.to_s)

        nome = nome_de_arquivo(dados["nome"])
        secao = SECOES.include?(dados["secao"]) ? dados["secao"] : nil
        categoria = dados["categoria"].to_s.strip
        return { ok: false, erro: "Falta o nome do bloco." } if nome.empty?
        return { ok: false, erro: "Escolha a secao do Memorial." } unless secao
        return { ok: false, erro: "Escolha ou digite a categoria." } if categoria.empty?

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

        meus = ler_meus(dir)
        meus << { "arquivo" => arq, "nome" => nome, "secao" => secao, "categoria" => categoria, "medida" => medida,
                  "mini" => (File.exist?(mini) ? mini_rel : nil), "meu" => true,
                  "adicionado_por" => ENV["USERNAME"].to_s, "data" => Time.now.strftime("%d/%m/%Y") }
        File.write(File.join(dir, MEUS), JSON.pretty_generate("versao" => 1, "blocos" => meus), encoding: "UTF-8")
        { ok: true, nome: nome, arquivo: arq }
      rescue StandardError => err
        { ok: false, erro: "Erro: #{err.message}" }
      end

      def self.ler_meus(dir)
        f = File.join(dir, MEUS)
        File.exist?(f) ? JSON.parse(File.read(f, encoding: "UTF-8"))["blocos"] : []
      rescue StandardError
        []
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
        ler_meus(dir).each { |b| indice[b["arquivo"]] ||= b.merge("meu" => true) }

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
