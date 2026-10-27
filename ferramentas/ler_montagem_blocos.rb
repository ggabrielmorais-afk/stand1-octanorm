# ler_montagem_blocos.rb — SO LEITURA. Abre blocos de referencia num arquivo vazio
# e grava a montagem de cada um (peca, posicao, giro, tamanho) em montagem_blocos.json.
# Serve pra o plugin colocar montante, travessa e folha no mesmo lugar que voces poem.
#
# Uso: SketchUp com arquivo NOVO e vazio, Console Ruby:
#   load 'G:/Outros computadores/Meu computador (1)/PROJETO CAD/TECH/stand1-octanorm/ler_montagem_blocos.rb'
# Feche o arquivo SEM salvar no fim.

require 'json'

module STAND1
  module OctanormMontagem
    CAT = "C:/Users/User/Documents/GABRIEL EMPRESA/Gabriel Stand 1/CATALOGO STAND1"
    BLOCOS = [
      "Parede em perfil de aluminio (uma folha).skp",
      "Parede Octanorm.skp",
      "Testeira em perfil de aluminio (uma folha).skp",
      "Porta Octanorm.skp",
      "PLuguin/Octanorm.skp",
      "PLuguin/Travesa.skp",
      "PLuguin/Z500.skp"
    ]
    SAIDA = File.join(File.dirname(__FILE__), "montagem_blocos.json")

    def self.cm(v); (v.to_f * 2.54).round(2); end
    def self.pt(p); [cm(p.x), cm(p.y), cm(p.z)]; end
    def self.vet(v); [v.x.round(3), v.y.round(3), v.z.round(3)]; end

    def self.caixa(b)
      { min: pt(b.min), max: pt(b.max), tam: [cm(b.width), cm(b.height), cm(b.depth)] }
    end

    # desce ate 4 niveis; anota cada grupo/componente com posicao no sistema do bloco
    def self.arvore(ents, tr, nivel)
      ents.grep(Sketchup::Group).to_a.concat(ents.grep(Sketchup::ComponentInstance).to_a).map do |e|
        t = tr * e.transformation
        d = e.definition
        bb = Geom::BoundingBox.new
        8.times { |i| bb.add(d.bounds.corner(i).transform(t)) }
        no = {
          tipo: e.is_a?(Sketchup::Group) ? "grupo" : "componente",
          nome: e.is_a?(Sketchup::Group) ? e.name.to_s : d.name,
          definicao: d.name,
          tag: e.layer.name,
          material: e.material ? e.material.display_name : nil,
          origem: pt(t.origin),
          eixo_x: vet(t.xaxis), eixo_y: vet(t.yaxis), eixo_z: vet(t.zaxis),
          escala: [t.xscale.round(3), t.yscale.round(3), t.zscale.round(3)],
          caixa_no_bloco: caixa(bb),
          caixa_propria: caixa(d.bounds),
          faces_soltas: d.entities.grep(Sketchup::Face).size
        }
        no[:filhos] = arvore(d.entities, t, nivel + 1) if nivel < 4
        no
      end
    end

    def self.rodar
      model = Sketchup.active_model
      saida = {}
      BLOCOS.each do |rel|
        arq = File.join(CAT, rel)
        unless File.exist?(arq)
          saida[rel] = { erro: "arquivo nao existe" }; next
        end
        model.entities.clear!
        model.definitions.purge_unused
        d = model.definitions.load(arq)
        saida[rel] = {
          caixa: caixa(d.bounds),
          faces_soltas: d.entities.grep(Sketchup::Face).size,
          pecas: arvore(d.entities, Geom::Transformation.new, 0)
        }
      end
      model.entities.clear!
      model.definitions.purge_unused
      File.write(SAIDA, JSON.pretty_generate(saida), encoding: "UTF-8")
      UI.messagebox("Montagem lida: #{saida.size} blocos.\n\n#{SAIDA}\n\nFeche este arquivo SEM salvar.")
    end
  end
end

STAND1::OctanormMontagem.rodar
