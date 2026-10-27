# desmontar_blocos.rb — SO LEITURA nos blocos originais.
# Abre Painel de vidro e Porta Octanorm num arquivo vazio e:
#   1. grava a montagem (peca, posicao, giro, tamanho) em montagem_vidro_porta.json
#   2. salva CADA peca diferente num .skp proprio em pecas_extraidas\<bloco>\
#      (spider, perfil de vidro, vidro, folha da porta, fechadura...)
#   Os blocos do catalogo nao sao alterados. Nao sobrescreve peca ja extraida.
#
# Uso: SketchUp com arquivo NOVO e vazio, Console Ruby:
#   load 'G:/Outros computadores/Meu computador (1)/PROJETO CAD/TECH/stand1-octanorm/desmontar_blocos.rb'
# Feche o arquivo SEM salvar no fim.

require 'json'
require 'fileutils'

module STAND1
  module OctanormDesmontar
    CAT = "C:/Users/User/Documents/GABRIEL EMPRESA/Gabriel Stand 1/CATALOGO STAND1"
    # 26/10/2026: pecas de vidro que o Gabriel separou em PLuguin
    BLOCOS = ["PLuguin/parede de vidro.skp", "PLuguin/Spider para vidro .skp", "PLuguin/Porta de vidro .skp"]
    PASTA = File.dirname(__FILE__)
    SAIDA = File.join(PASTA, "montagem_vidro_v2.json")
    EXTRAIDAS = File.join(PASTA, "pecas_extraidas")

    def self.cm(v); (v.to_f * 2.54).round(2); end
    def self.pt(p); [cm(p.x), cm(p.y), cm(p.z)]; end
    def self.vet(v); [v.x.round(3), v.y.round(3), v.z.round(3)]; end
    def self.caixa(b); { min: pt(b.min), max: pt(b.max), tam: [cm(b.width), cm(b.height), cm(b.depth)] }; end
    def self.arquivo_ok(nome); nome.to_s.gsub(/[\\\/:*?"<>|#]/, "-").strip; end

    def self.arvore(ents, tr, nivel, defs)
      ents.grep(Sketchup::Group).to_a.concat(ents.grep(Sketchup::ComponentInstance).to_a).map do |e|
        t = tr * e.transformation
        d = e.definition
        defs[d] = (e.is_a?(Sketchup::Group) && !e.name.to_s.empty?) ? e.name : d.name
        bb = Geom::BoundingBox.new
        8.times { |i| bb.add(d.bounds.corner(i).transform(t)) }
        no = {
          tipo: e.is_a?(Sketchup::Group) ? "grupo" : "componente",
          nome: e.is_a?(Sketchup::Group) ? e.name.to_s : d.name,
          definicao: d.name, tag: e.layer.name,
          material: e.material ? e.material.display_name : nil,
          origem: pt(t.origin), eixo_x: vet(t.xaxis), eixo_y: vet(t.yaxis), eixo_z: vet(t.zaxis),
          escala: [t.xscale.round(3), t.yscale.round(3), t.zscale.round(3)],
          caixa_no_bloco: caixa(bb), caixa_propria: caixa(d.bounds),
          faces_soltas: d.entities.grep(Sketchup::Face).size
        }
        no[:filhos] = arvore(d.entities, t, nivel + 1, defs) if nivel < 5
        no
      end
    end

    def self.rodar
      model = Sketchup.active_model
      unless model.entities.length == 0 && model.path.to_s.empty?
        UI.messagebox("Rode num arquivo NOVO e vazio. Nada foi feito."); return
      end
      saida = {}
      salvas = 0
      BLOCOS.each do |rel|
        arq = File.join(CAT, rel)
        next saida[rel] = { erro: "arquivo nao existe" } unless File.exist?(arq)

        model.entities.clear!
        model.definitions.purge_unused
        d = model.definitions.load(arq)
        defs = {}
        saida[rel] = { caixa: caixa(d.bounds), pecas: arvore(d.entities, Geom::Transformation.new, 0, defs) }

        pasta = File.join(EXTRAIDAS, File.basename(rel, ".skp"))
        FileUtils.mkdir_p(pasta)
        lista = []
        defs.each do |defn, nome|
          destino = File.join(pasta, "#{arquivo_ok(nome)} - #{arquivo_ok(defn.name)}.skp")
          lista << { nome: nome, definicao: defn.name, arquivo: File.basename(destino), caixa: caixa(defn.bounds) }
          next if File.exist?(destino)

          begin
            salvas += 1 if defn.save_as(destino)
          rescue => e
            lista.last[:erro] = e.message
          end
        end
        saida[rel][:pecas_salvas] = lista
      end
      model.entities.clear!
      model.definitions.purge_unused
      File.write(SAIDA, JSON.pretty_generate(saida), encoding: "UTF-8")
      UI.messagebox("Desmontado: #{salvas} pecas salvas em\n#{EXTRAIDAS}\n\nMontagem: #{SAIDA}\n\nFeche este arquivo SEM salvar.")
    end
  end
end

STAND1::OctanormDesmontar.rodar
