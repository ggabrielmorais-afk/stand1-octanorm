# encoding: UTF-8
# ruby tests/test_biblioteca.rb  (Ruby comum, sem SketchUp)
require 'minitest/autorun'
require_relative '../biblioteca'

B = STAND1::Octanorm::Biblioteca

class TestSlug < Minitest::Test
  def test_remove_acento_e_espaco
    assert_equal "joao_silva", B.slug("João Silva")
    assert_equal "maria", B.slug("  Maria  ")
  end

  def test_vazio_vira_pessoa
    assert_equal "pessoa", B.slug("")
    assert_equal "pessoa", B.slug(nil)
  end
end

require 'tmpdir'

class TestAssinaturaDaPasta < Minitest::Test
  def test_muda_quando_entra_bloco_ou_lista_e_ignora_o_resto
    Dir.mktmpdir do |d|
      File.write(File.join(d, "Balcao 1,00.skp"), "x")
      a = B.assinatura(d)
      File.write(File.join(d, "anotacao.txt"), "x") # arquivo que nao e bloco: nao conta
      assert_equal a, B.assinatura(d)
      File.write(File.join(d, "Totem.skp"), "x")
      b = B.assinatura(d)
      refute_equal a, b
      File.write(File.join(d, "meus_blocos_fagner.json"), "{}")
      refute_equal b, B.assinatura(d)
    end
  end

  def test_pasta_que_nao_existe_nao_quebra
    assert_equal "", B.assinatura("Z:/nao/existe")
    assert_equal "", B.assinatura(nil)
  end
end

class TestNovidades < Minitest::Test
  def entrada(nome, autor, quando)
    { "nome" => nome, "categoria" => "Balcões", "adicionado_por" => autor, "adicionado_em" => quando }
  end

  def test_primeira_vez_nesta_maquina_nao_avisa_nada
    entradas = [entrada("X", "Maria", "2026-10-28T10:00:00")]
    assert_equal [], B.novidades(entradas, nil, "João")
  end

  def test_filtra_por_data_e_ignora_as_proprias
    entradas = [
      entrada("Antigo", "Maria", "2026-10-28T09:00:00"),  # antes da ultima visita: nao avisa
      entrada("Novo da Maria", "Maria", "2026-10-28T11:00:00"),
      entrada("Meu proprio", "João", "2026-10-28T12:00:00") # meu: nao avisa sobre mim mesmo
    ]
    r = B.novidades(entradas, "2026-10-28T10:00:00", "João")
    assert_equal ["Novo da Maria"], r.map { |b| b["nome"] }
  end

  def test_timestamp_tem_milissegundo
    assert_match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}\z/, B.agora)
  end

  def test_ordena_do_mais_antigo_pro_mais_novo
    entradas = [entrada("B", "Maria", "2026-10-28T12:00:00"), entrada("A", "Maria", "2026-10-28T11:00:00")]
    r = B.novidades(entradas, "2026-10-28T10:00:00", "João")
    assert_equal %w[A B], r.map { |b| b["nome"] }
  end
end
