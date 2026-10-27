# ler_modelo_referencia.rb — SO LEITURA. Nao altera nem salva o modelo aberto.
# Lista todos os componentes/grupos do modelo aberto: nome, quantidade, medida, tag.
# Serve pra aprender o padrao de Octanorm de um stand real (ex.: Modelagem FLASO.skp).
#
# Uso: abra o stand no SketchUp, Console Ruby:
#   load 'G:/Outros computadores/Meu computador (1)/PROJETO CAD/TECH/stand1-octanorm/ler_modelo_referencia.rb'

module STAND1
  module OctanormLeitura
    SAIDA = File.join(File.dirname(__FILE__), "referencia_#{File.basename(Sketchup.active_model.path.to_s, '.skp')}.csv")

    def self.cm(v); (v.to_f * 2.54).round(1); end

    def self.rodar
      model = Sketchup.active_model
      acc = Hash.new { |h, k| h[k] = { qtd: 0, tags: {}, niveis: {}, pais: {} } }
      andar = lambda do |ents, nivel, pai, tr|
        ents.each do |e|
          next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)

          d = e.definition
          b = d.bounds
          t = tr * e.transformation
          esc = [t.xscale, t.yscale, t.zscale].map { |s| s.round(3) }
          dims = [cm(b.width * esc[0]), cm(b.height * esc[1]), cm(b.depth * esc[2])]
          tipo = e.is_a?(Sketchup::Group) ? "grupo" : "componente"
          nome = e.is_a?(Sketchup::Group) ? (e.name.to_s.empty? ? "(grupo sem nome)" : e.name) : d.name
          k = [tipo, nome, dims.join(" x ")]
          acc[k][:qtd] += 1
          acc[k][:tags][e.layer.name] = true
          acc[k][:niveis][nivel] = true
          acc[k][:pais][pai] = true
          andar.call(d.entities, nivel + 1, nome, t) if nivel < 6
        end
      end
      andar.call(model.entities, 0, "(raiz)", Geom::Transformation.new)

      File.open(SAIDA, "w:UTF-8") do |f|
        f.write("\uFEFF")
        f.puts "tipo;nome;L x P x A (cm);quantidade;tags;nivel;dentro de"
        acc.sort_by { |k, v| [-v[:qtd], k[1]] }.each do |k, v|
          f.puts [k[0], k[1], k[2], v[:qtd], v[:tags].keys.join(" | "), v[:niveis].keys.sort.join(","),
                  v[:pais].keys.first(3).join(" | ")].map { |x| x.to_s.gsub(/[;\r\n]/, " ") }.join(";")
        end
      end
      UI.messagebox("Leitura pronta: #{acc.size} tipos de peca.\n\n#{SAIDA}\n\nO modelo nao foi alterado.")
    end
  end
end

STAND1::OctanormLeitura.rodar
