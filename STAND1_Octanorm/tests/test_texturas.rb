# encoding: UTF-8
# ruby tests/test_texturas.rb  (Ruby comum, sem SketchUp)
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'zlib'
require 'json'
require_relative '../texturas'

T = STAND1::Octanorm::Texturas

# Zip minimo (1 arquivo, deflate) pra testar a leitura da miniatura.
def zip_com(nome, conteudo)
  dados = Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, -Zlib::MAX_WBITS).deflate(conteudo, Zlib::FINISH)
  crc = Zlib.crc32(conteudo)
  local = ["PK\x03\x04".b, 20, 0, 8, 0, 0, crc, dados.bytesize, conteudo.bytesize, nome.bytesize, 0].pack("a4vvvvvVVVvv") + nome + dados
  central = ["PK\x01\x02".b, 20, 20, 0, 8, 0, 0, crc, dados.bytesize, conteudo.bytesize, nome.bytesize, 0, 0, 0, 0, 0, 0]
            .pack("a4vvvvvvVVVvvvvvVV") + nome
  fim = ["PK\x05\x06".b, 0, 0, 1, 1, central.bytesize, local.bytesize, 0].pack("a4vvvvVVv")
  local + central + fim
end

class TestDescreverNapa < Minitest::Test
  def test_codigo_e_cor
    d = T.descrever("NAPA 37324 BRANCO - MSKP.skm")
    assert_equal "NAPA 37324 BRANCO", d[:nome]
    assert_equal "37324", d[:codigo]
    assert_equal "BRANCO", d[:cor]
    assert_equal "NAPA 37324 BRANCO - MSKP.skm", d[:arquivo]
  end

  def test_cor_com_duas_palavras
    d = T.descrever("NAPA 41106 AZUL BAHIA - MSKP.skm")
    assert_equal "AZUL BAHIA", d[:cor]
    assert_equal "41106", d[:codigo]
  end

  def test_nome_fora_do_padrao_nao_quebra
    d = T.descrever("NAPA BRANCA.skm")
    assert_equal "", d[:codigo]
    assert_equal "NAPA BRANCA", d[:cor]
  end
end

class TestListarNapas < Minitest::Test
  def test_so_entra_napa_da_raiz_da_pasta
    Dir.mktmpdir do |d|
      %w[NAPA\ 41106\ AZUL\ BAHIA\ -\ MSKP.skm NAPA\ 37324\ BRANCO\ -\ MSKP.skm NAPA\ 37327\ VERMELHO\ -\ MSKP.skm
         TAPETE\ 01\ -\ MSKP.skm leia-me.txt].each { |f| File.binwrite(File.join(d, f), "x") }
      FileUtils.mkdir_p(File.join(d, "outra"))
      File.binwrite(File.join(d, "outra", "NAPA 99999 ESCONDIDA - MSKP.skm"), "x") # subpasta nao entra
      lista = T.listar(d)
      assert_equal ["AZUL BAHIA", "BRANCO", "VERMELHO"], lista.map { |n| n[:cor] }
    end
  end

  def test_pasta_inexistente_ou_nula
    assert_equal [], T.listar("Z:/nao/existe")
    assert_equal [], T.listar(nil)
  end
end

class TestResolver < Minitest::Test
  def test_so_aceita_napa_dentro_da_pasta
    Dir.mktmpdir do |d|
      File.binwrite(File.join(d, "NAPA 37324 BRANCO - MSKP.skm"), "x")
      File.binwrite(File.join(d, "TAPETE 01 - MSKP.skm"), "x")
      assert_equal File.join(d, "NAPA 37324 BRANCO - MSKP.skm"), T.resolver(d, "NAPA 37324 BRANCO - MSKP.skm")
      assert_nil T.resolver(d, "TAPETE 01 - MSKP.skm")                  # nao e napa
      assert_nil T.resolver(d, "NAPA 11111 NAO EXISTE - MSKP.skm")
      assert_nil T.resolver(d, "")
      assert_nil T.resolver(d, "NAPA 37324 BRANCO - MSKP.txt")
    end
  end

  def test_caminho_com_subpasta_vira_so_o_nome_do_arquivo
    Dir.mktmpdir do |d|
      File.binwrite(File.join(d, "NAPA 37324 BRANCO - MSKP.skm"), "x")
      # quem manda "..\\..\\NAPA ..." cai no arquivo da pasta certa, nunca fora dela
      r = T.resolver(d, '..\\..\\NAPA 37324 BRANCO - MSKP.skm')
      assert_equal File.join(d, "NAPA 37324 BRANCO - MSKP.skm"), r
    end
  end
end

class TestCarpete < Minitest::Test
  def manifesto_em(dir, itens, tamanho = 0.5)
    File.write(File.join(dir, "carpetes.json"), JSON.generate("categoria" => "Forração carpete", "tamanho_m" => tamanho, "itens" => itens),
               encoding: "UTF-8")
  end

  def test_nome_no_padrao_da_stand1
    assert_equal "Forração carpete grafite", T.nome_carpete("grafite")
    assert_equal "Forração carpete azul bic N", T.nome_carpete(" azul bic N ")
    assert_equal "Forração carpete", T::CAT_CARPETE
    assert_equal "Napa", T::CAT_NAPA
  end

  def test_so_entra_o_que_tem_o_jpg_na_pasta
    Dir.mktmpdir do |d|
      FileUtils.mkdir_p(File.join(d, "mini"))
      File.binwrite(File.join(d, "a.jpg"), "x")
      File.binwrite(File.join(d, "mini", "a.jpg"), "x")
      manifesto_em(d, [{ "cor" => "preto", "arquivo" => "a.jpg" }, { "cor" => "sumiu", "arquivo" => "b.jpg" }])
      lista = T.carpetes(d)
      assert_equal ["Forração carpete preto"], lista.map { |c| c[:nome] }
      assert_equal File.join(d, "a.jpg"), T.resolver_carpete("a.jpg", d)
      assert_equal File.join(d, "mini", "a.jpg"), T.resolver_carpete("a.jpg", d, true)
      assert_nil T.resolver_carpete("b.jpg", d)
      assert_nil T.resolver_carpete("../a.jpg.exe", d)
    end
  end

  def test_resolver_ignora_pasta_no_caminho
    Dir.mktmpdir do |d|
      File.binwrite(File.join(d, "a.jpg"), "x")
      manifesto_em(d, [{ "cor" => "preto", "arquivo" => "a.jpg" }])
      assert_equal File.join(d, "a.jpg"), T.resolver_carpete('..\\..\\a.jpg', d)
    end
  end

  def test_tamanho_do_manifesto_ou_padrao
    Dir.mktmpdir do |d|
      manifesto_em(d, [], 0.8)
      assert_in_delta 0.8, T.tamanho_carpete(d), 1e-9
      manifesto_em(d, [], 0)
      assert_in_delta T::TAMANHO_PADRAO_M, T.tamanho_carpete(d), 1e-9
    end
    assert_in_delta T::TAMANHO_PADRAO_M, T.tamanho_carpete("Z:/nao/existe"), 1e-9
  end

  def test_pasta_sem_manifesto_nao_quebra
    assert_equal [], T.carpetes("Z:/nao/existe")
  end

  def test_ids_da_janela
    assert_equal ["napa", "NAPA 37324 BRANCO - MSKP.skm"], T.separar_id("napa:NAPA 37324 BRANCO - MSKP.skm")
    assert_equal ["carpete", "forracao_carpete_preto.jpg"], T.separar_id("carpete:forracao_carpete_preto.jpg")
    assert_equal ["", ""], T.separar_id(nil)
  end

  def test_as_20_cores_que_vem_no_plugin
    lista = T.carpetes
    assert_equal 20, lista.size
    assert_equal lista.size, lista.map { |c| c[:nome] }.uniq.size
    assert lista.all? { |c| c[:nome].start_with?("Forração carpete ") }
    %w[preto grafite cinza violeta laranja amarelo].each { |cor| assert_includes lista.map { |c| c[:cor] }, cor }
    lista.each do |c|
      assert T.resolver_carpete(c[:arquivo]), "sem jpg: #{c[:arquivo]}"
      assert T.resolver_carpete(c[:arquivo], T::CARPETE_DIR, true), "sem miniatura: #{c[:arquivo]}"
    end
  end
end

class TestMiniatura < Minitest::Test
  def test_le_a_miniatura_do_zip
    Dir.mktmpdir do |d|
      png = "\x89PNG fake miniatura".b
      f = File.join(d, "NAPA 1 X - MSKP.skm")
      File.binwrite(f, zip_com("doc_thumbnail.png", png))
      assert_equal png, T.ler_do_zip(f)
    end
  end

  def test_zip_sem_miniatura_ou_arquivo_que_nao_existe
    Dir.mktmpdir do |d|
      f = File.join(d, "NAPA 1 X - MSKP.skm")
      File.binwrite(f, zip_com("document.xml", "<x/>"))
      assert_nil T.ler_do_zip(f)
    end
    assert_nil T.ler_do_zip("Z:/nao/existe.skm")
  end

  def test_miniatura_de_napa_real_se_existir
    real = File.join(T.padrao, "NAPA 37324 BRANCO - MSKP.skm")
    skip "biblioteca do Hugo nao instalada" unless File.exist?(real)
    png = T.ler_do_zip(real)
    assert png && png.start_with?("\x89PNG".b)
  end

  def test_napas_reais_se_existirem
    skip "biblioteca do Hugo nao instalada" unless File.directory?(T.padrao)
    lista = T.listar(T.padrao)
    assert_operator lista.size, :>=, 10 # na maquina do Gabriel sao 19
    assert lista.all? { |n| n[:codigo] =~ /\A\d+\z/ }
  end
end
