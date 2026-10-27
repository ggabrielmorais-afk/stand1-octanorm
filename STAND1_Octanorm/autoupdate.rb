# encoding: UTF-8
# autoupdate.rb — atualizacao automatica pelo GitHub do Gabriel
# (ggabrielmorais-afk/stand1-octanorm), mesmo esquema do Concha Render:
# so instala .rbz deste repositorio, por https, com o sha256 do latest.json
# conferido. Sem sha256 (ou endereco de fora), nao instala: abre a pagina.
# Como o Octanorm nao tem janela propria, o aviso e uma pergunta "Instalar agora?".

require 'json'
require 'tmpdir'
require 'digest'

module STAND1
  module Octanorm
    module AutoUpdate
      RAW = 'https://raw.githubusercontent.com/ggabrielmorais-afk/stand1-octanorm/'.freeze
      URL_MANIFESTO = "#{RAW}main/latest.json".freeze
      PAGINA = 'https://github.com/ggabrielmorais-afk/stand1-octanorm'.freeze

      # Versao instalada = a que o loader registra no SketchUp (fonte unica).
      def self.versao_local
        ext = (Sketchup.extensions['STAND1 Octanorm'] rescue nil)
        v = ext && ext.version.to_s
        return v unless v.nil? || v.empty?

        loader = File.join(File.dirname(__dir__), 'STAND1_Octanorm_loader.rb')
        (File.read(loader)[/version\s*=\s*'([\d.]+)'/, 1] rescue nil) || '0'
      end

      # Compara "a.b.c" numericamente: remota > local?
      def self.maior?(remota, local)
        r = remota.to_s.split('.').map(&:to_i)
        l = local.to_s.split('.').map(&:to_i)
        n = [r.size, l.size].max
        r += [0] * (n - r.size)
        l += [0] * (n - l.size)
        (r <=> l) > 0
      end

      # O .rbz so pode vir deste repositorio: sem "..", sem %, sem outro dominio.
      def self.url_do_repo?(url)
        u = url.to_s
        return false unless u.start_with?(RAW) && u.end_with?('.rbz')

        resto = u[RAW.size..-1]
        !resto.include?('..') && resto.match?(%r{\A[A-Za-z0-9._/-]+\z})
      end

      def self.sha_valido?(sha)
        sha.to_s.strip.match?(/\A[0-9a-fA-F]{64}\z/)
      end

      # O arquivo baixado bate com o sha256 do latest.json?
      def self.confere?(conteudo, sha)
        sha_valido?(sha) && Digest::SHA256.hexdigest(conteudo.to_s) == sha.to_s.strip.downcase
      end

      # [:nova, dados] | [:em_dia, nil] | [:invalida, nil]
      def self.avaliar(info, local)
        return [:invalida, nil] unless info.is_a?(Hash)

        nova = info['versao'].to_s
        return [:em_dia, nil] unless maior?(nova, local)
        return [:invalida, nil] unless url_do_repo?(info['rbz']) && sha_valido?(info['sha256'])

        [:nova, { versao: nova, notas: info['notas'].to_s, rbz: info['rbz'].to_s, sha256: info['sha256'].to_s.strip.downcase }]
      end

      # GET assincrono. Prioriza Sketchup::Http (pilha nativa do Windows).
      def self.http_async(url, &on_body)
        if defined?(Sketchup::Http) && defined?(Sketchup::Http::Request)
          req = Sketchup::Http::Request.new(url, Sketchup::Http::GET)
          (@http_reqs ||= []) << req # sem reter, o GC coleta antes do callback
          req.start do |request, response|
            (@http_reqs ||= []).delete(request) rescue nil
            code = response.respond_to?(:status_code) ? response.status_code.to_i : 0
            body = response.respond_to?(:body) ? response.body : nil
            on_body.call(code >= 200 && code < 400 && body && !body.empty? ? body : nil, code >= 200 && code < 400)
          end
        else
          on_body.call(nil, false)
        end
      rescue StandardError
        on_body.call(nil, false)
      end

      # manual = true avisa tambem quando nao ha atualizacao (menu "Verificar atualizacao").
      def self.check(manual = false)
        http_async(URL_MANIFESTO) do |body, ok|
          unless ok && body
            UI.messagebox("Nao foi possivel verificar atualizacao agora.") if manual
            next
          end
          begin
            limpo = body.to_s.dup.force_encoding('UTF-8').scrub('').sub(/\A﻿/, '')
            estado, dados = avaliar(JSON.parse(limpo), versao_local)
            case estado
            when :nova
              msg = "STAND1 Octanorm #{dados[:versao]} disponivel (voce tem #{versao_local}).\n\n#{dados[:notas]}\n\nInstalar agora?"
              install(dados[:rbz], dados[:sha256]) if UI.messagebox(msg, MB_YESNO) == IDYES
            when :em_dia
              UI.messagebox("STAND1 Octanorm esta atualizado (#{versao_local}).") if manual
            else
              UI.messagebox("A atualizacao publicada nao passou na conferencia.\nAbrindo a pagina do projeto.") if manual
              UI.openURL(PAGINA) if manual
            end
          rescue StandardError
            UI.messagebox("Nao foi possivel ler a atualizacao.") if manual
          end
        end
      end

      # Baixa o .rbz, confere o sha256 e instala via API nativa.
      def self.install(url, sha)
        http_async(url) do |body, ok|
          if !ok || body.nil?
            UI.messagebox("Nao foi possivel baixar a atualizacao.\nAbrindo a pagina do projeto.")
            UI.openURL(PAGINA) rescue nil
            next
          end
          unless confere?(body, sha)
            UI.messagebox("O arquivo baixado nao bate com a assinatura (sha256). Nada foi instalado.\nAbrindo a pagina do projeto.")
            UI.openURL(PAGINA) rescue nil
            next
          end
          begin
            destino = File.join(Dir.tmpdir, 'STAND1_Octanorm_update.rbz')
            File.open(destino, 'wb') { |f| f.write(body) }
            Sketchup.install_from_archive(destino)
            UI.messagebox("Atualizacao instalada.\n\nReinicie o SketchUp para concluir.")
          rescue StandardError => e
            UI.messagebox("Falha ao instalar a atualizacao:\n#{e.message}")
          end
        end
      end
    end
  end
end
