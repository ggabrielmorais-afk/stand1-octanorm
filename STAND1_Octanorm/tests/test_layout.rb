# encoding: UTF-8
# ruby tests/test_layout.rb  (Ruby comum, sem SketchUp)
require 'minitest/autorun'
require_relative '../layout'

L = STAND1::Octanorm::Layout

class TestFolhas < Minitest::Test
  def test_parede_exata_de_3m
    r = L.folhas(300)
    assert_equal 3, r[:folhas].size
    assert(r[:folhas].none? { |f| f[:especial] })
    assert_nil r[:aviso]
  end

  def test_sobra_vira_folha_especial
    r = L.folhas(330)
    assert_equal 4, r[:folhas].size
    assert_equal 30.0, r[:folhas].last[:largura]
    assert r[:folhas].last[:especial]
  end

  def test_sobra_pequena_vira_aviso
    r = L.folhas(302)
    assert_equal 3, r[:folhas].size
    assert_match(/sobra de 2 cm/, r[:aviso])
  end

  def test_parede_menor_que_um_modulo
    r = L.folhas(60)
    assert_equal 1, r[:folhas].size
    assert_equal 60.0, r[:folhas].first[:largura]
  end

  def test_erro_de_arredondamento_nao_cria_folha
    r = L.folhas(299.995)
    assert_equal 3, r[:folhas].size
  end

  def test_comprimento_zero_da_erro
    assert_raises(ArgumentError) { L.folhas(0) }
  end
end

class TestTrechos < Minitest::Test
  def test_parede_em_l_nao_duplica_montante_no_canto
    t = L.trechos([[0, 0], [300, 0], [300, 200]])
    assert_equal 2, t.size
    assert t[0][:montante_inicio]
    refute t[1][:montante_inicio]
    assert_equal [300.0, 200.0], [t[0][:comprimento], t[1][:comprimento]]
  end

  def test_sala_fechada_tem_4_trechos_sem_montante_duplicado
    t = L.trechos([[0, 0], [300, 0], [300, 300], [0, 300]], true)
    assert_equal 4, t.size
    assert(t.none? { |x| x[:montante_inicio] })
    assert(t.all? { |x| x[:montante_fim] })
  end

  def test_ponto_repetido_e_ignorado
    t = L.trechos([[0, 0], [0, 0], [200, 0]])
    assert_equal 1, t.size
  end

  def test_um_ponto_so_da_erro
    assert_raises(ArgumentError) { L.trechos([[0, 0]]) }
  end
end

class TestEncaixe < Minitest::Test
  def test_eixos_de_parede_de_3m_sao_4_montantes
    assert_equal [[0.0, 0.0], [100.0, 0.0], [200.0, 0.0], [300.0, 0.0]], L.eixos(L.trechos([[0, 0], [300, 0]]))
  end

  def test_eixos_nao_repete_o_canto
    e = L.eixos(L.trechos([[0, 0], [200, 0], [200, 100]]))
    assert_equal 4, e.size
  end

  def test_parede_que_encosta_em_montante_existente_nao_duplica
    t = L.trechos([[100, 0], [100, 300]], false, [[100, 0]])
    refute t[0][:montante_inicio]
    assert t[0][:montante_fim]
  end

  def test_parede_que_fecha_nos_dois_lados
    t = L.trechos([[0, 0], [0, 200]], false, [[0, 0], [0, 200]])
    refute t[0][:montante_inicio]
    refute t[0][:montante_fim]
  end
end

class TestPorta < Minitest::Test
  def test_porta_padrao_no_ultimo_vao_do_ultimo_trecho
    t = L.trechos([[0, 0], [300, 0], [300, 200]])
    assert_equal({ trecho: 1, vao: 1 }, L.porta_padrao(t))
  end

  def test_porta_padrao_pula_folha_especial
    t = L.trechos([[0, 0], [250, 0]]) # 2 folhas de 1 m + especial de 50
    assert_equal({ trecho: 0, vao: 1 }, L.porta_padrao(t))
  end

  def test_sem_vao_inteiro_nao_tem_porta
    assert_nil L.porta_padrao(L.trechos([[0, 0], [60, 0]]))
  end

  def test_clique_escolhe_o_vao_mais_perto
    t = L.trechos([[0, 0], [300, 0], [300, 300]])
    assert_equal({ trecho: 0, vao: 1 }, L.vao_no_ponto(t, 150, 20))
    assert_equal({ trecho: 1, vao: 2 }, L.vao_no_ponto(t, 320, 250))
  end

  def test_clique_em_folha_especial_nao_vale
    t = L.trechos([[0, 0], [250, 0]])
    assert_nil L.vao_no_ponto(t, 230, 5)
  end
end

class TestMeioModulo < Minitest::Test
  def test_vidro_350_vira_3_inteiros_e_1_meio
    r = L.folhas(350, meio: true)
    assert_equal 4, r[:folhas].size
    assert r[:folhas].last[:meio]
    refute r[:folhas].last[:especial]
  end

  def test_ts_350_tambem_usa_folha_de_50
    r = L.folhas(350)
    assert r[:folhas].last[:meio]
    refute r[:folhas].last[:especial]
  end

  def test_meio_pode_ser_desligado
    assert L.folhas(350, meio: false)[:folhas].last[:especial]
  end

  def test_sobra_fora_da_tolerancia_continua_especial
    assert L.folhas(370, meio: true)[:folhas].last[:especial]
  end

  def test_porta_nao_entra_no_meio
    t = L.trechos([[0, 0], [250, 0]])
    assert_equal({ trecho: 0, vao: 1 }, L.porta_padrao(t, meio: true))
    assert_nil L.vao_no_ponto(t, 230, 5, meio: true)
  end

  def test_resumo_conta_meios
    r = L.resumo(L.trechos([[0, 0], [250, 0]]), 220, meio: true)
    assert_equal 2, r[:folhas_normais]
    assert_equal 1, r[:folhas_meio]
    assert_equal 0, r[:folhas_especiais]
  end

  def test_eixos_com_meio
    e = L.eixos(L.trechos([[0, 0], [150, 0]]), meio: true)
    assert_equal [[0.0, 0.0], [100.0, 0.0], [150.0, 0.0]], e
  end
end

class TestTesteiraIlha < Minitest::Test
  def test_testeira_reta_tem_2_apoios
    assert_equal [[0, :inicio], [0, :fim]], L.apoios_ate_chao(L.trechos([[0, 0], [400, 0]]))
  end

  def test_testeira_em_l_tem_3_apoios
    assert_equal 3, L.apoios_ate_chao(L.trechos([[0, 0], [400, 0], [400, 300]])).size
  end

  def test_ilha_fechada_4x3_tem_4_apoios_nos_cantos
    t = L.trechos([[0, 0], [400, 0], [400, 300], [0, 300]], true)
    assert_equal 4, L.apoios_ate_chao(t).size
  end
end

class TestTeto < Minitest::Test
  def test_grade_de_3m_tem_4_linhas
    assert_equal [0.0, 100.0, 200.0, 300.0], L.grade(300)
  end

  def test_grade_usa_meio_modulo
    assert_equal [0.0, 100.0, 200.0, 250.0], L.grade(250)
  end

  def test_retangulo_da_sala_alinhada
    r = L.retangulo_da_sala([[0, 0], [400, 0], [400, 300], [0, 300]])
    assert_equal [0.0, 0.0], r[:origem]
    assert_equal 400.0, r[:l]
    assert_equal 300.0, r[:p]
    assert_in_delta 0.0, r[:angulo], 1e-9
  end

  def test_retangulo_da_sala_desenhada_ao_contrario
    # sala desenhada no sentido horario: o teto continua cobrindo a sala
    r = L.retangulo_da_sala([[0, 300], [400, 300], [400, 0], [0, 0]])
    assert_equal 400.0, r[:l]
    assert_equal 300.0, r[:p]
    assert_equal [0.0, 0.0], r[:origem]
  end

  def test_retangulo_da_sala_girada_90
    r = L.retangulo_da_sala([[0, 0], [0, 300], [-400, 300], [-400, 0]])
    assert_equal 300.0, r[:l]
    assert_equal 400.0, r[:p]
    assert_in_delta Math::PI / 2, r[:angulo], 1e-9
  end

  def test_ler_dimensoes
    assert_equal [300.0, 400.0], L.ler_dimensoes("3x4")
    assert_equal [350.0, 200.0], L.ler_dimensoes("3,5 x 2")
    assert_equal [300.0, 300.0], L.ler_dimensoes("3;3")
    assert_nil L.ler_dimensoes("3")
    assert_nil L.ler_dimensoes("abc x 2")
  end

  def test_grade_estica_sobra_pequena
    assert_equal [0.0, 100.0, 200.0, 302.0], L.grade(302)
  end

  # paredes de uma sala 4 x 3 no sistema do teto
  SALA = [[[0, 0], [400, 0]], [[400, 0], [400, 300]], [[400, 300], [0, 300]], [[0, 300], [0, 0]]].freeze

  def test_teto_solto_3x3_tem_grade_inteira
    r = L.teto_pecas(300, 300)
    assert_equal 24, r[:vigas].size # 4 linhas x 3 + 4 colunas x 3
    assert_equal 16, r[:nos].size
  end

  def test_teto_em_cima_da_sala_nao_repete_a_borda
    lados = L.lados_cobertos(400, 300, SALA)
    assert_equal [true, true, true, true], lados
    r = L.teto_pecas(400, 300, lados)
    assert_equal 17, r[:vigas].size # 2 linhas x 4 + 3 colunas x 3, so por dentro
    assert_equal 6, r[:nos].size
    assert_empty L.cantos_soltos(400, 300, SALA)
  end

  def test_lado_coberto_por_duas_paredes_em_linha
    segs = [[[0, 0], [200, 0]], [[200, 0], [400, 0]]]
    assert_equal [true, false, false, false], L.lados_cobertos(400, 300, segs)
  end

  def test_parede_em_l_deixa_um_canto_solto
    segs = [[[0, 0], [300, 0]], [[300, 0], [300, 300]]]
    assert_equal [true, true, false, false], L.lados_cobertos(300, 300, segs)
    soltos = L.cantos_soltos(300, 300, segs)
    assert_equal [[0.0, 300.0]], soltos
    r = L.teto_pecas(300, 300, L.lados_cobertos(300, 300, segs), soltos)
    refute_includes r[:nos], [0.0, 300.0] # no lugar do no vai o montante ate o chao
  end

  def test_teto_sem_parede_tem_4_cantos_soltos
    assert_equal 4, L.cantos_soltos(300, 200, []).size
    r = L.teto_pecas(300, 200, [false] * 4, L.cantos_soltos(300, 200, []))
    assert_equal 17, r[:vigas].size
    assert_equal 8, r[:nos].size
  end

  def test_no_teto_girado
    assert_equal [100.0, 50.0], L.no_teto([100, 50], [0, 0], 0.0)
    assert_equal [100.0, 0.0], L.no_teto([0, 100], [0, 0], Math::PI / 2)
    assert_equal [0.0, 0.0], L.no_teto([450, 300], [450, 300], Math::PI)
  end

  def test_pontas_sem_montante_na_sala_de_4_50
    # parede de baixo: montantes 0..400 + 450; de cima (desenhada ao contrario): 450, 350 ... 50, 0
    baixo = [0, 100, 200, 300, 400, 450].map { |x| [x, 0] }
    cima = [450, 350, 250, 150, 50, 0].map { |x| [x, 300] }
    lados = [true, false, true, false]
    assert_equal 4, L.pontas_sem_montante(450, 300, lados, baixo + cima)
    assert_equal 0, L.pontas_sem_montante(450, 300, [true, false, false, false], baixo)
  end
end

class TestLadoDeFora < Minitest::Test
  def test_sala_anti_horaria_nao_espelha
    refute L.horario?([[0, 0], [400, 0], [400, 300], [0, 300]])
  end

  def test_sala_horaria_espelha
    assert L.horario?([[0, 0], [0, 300], [400, 300], [400, 0]])
  end

  def test_parede_em_l_segue_o_canto
    refute L.horario?([[0, 0], [300, 0], [300, 300]])
    assert L.horario?([[300, 300], [300, 0], [0, 0]])
  end

  def test_parede_reta_nao_espelha
    refute L.horario?([[0, 0], [400, 0]])
    refute L.horario?([[400, 0], [0, 0]])
  end
end

class TestNomeMemorial < Minitest::Test
  def test_parede_e_testeira
    assert_equal "Parede em perfil de alumínio com fechamento em TS", L.nome_memorial("Parede", :ts)
    assert_equal "Testeira em perfil de alumínio com fechamento em vidro", L.nome_memorial("Testeira", "vidro")
    assert_equal "Parede em perfil de alumínio sem fechamento", L.nome_memorial("Parede", :estrutura)
  end

  def test_ambiente_comeca_pelo_tipo
    assert_equal "Depósito de apoio", L.nome_ambiente("Deposito", " de apoio ")
    assert_equal "Sala", L.nome_ambiente("Sala", "")
    assert_equal "Sala", L.nome_ambiente("xyz")
    assert_equal "Depósito em perfil de alumínio com fechamento em MDF",
                 L.nome_memorial(L.nome_ambiente("Deposito"), :mdf)
  end
end

class TestMeioModuloMesmoLado < Minitest::Test
  def montantes_em_y(trechos, y)
    L.eixos(trechos).select { |q| (q[1] - y).abs < 0.5 }.map { |q| q[0] }.sort
  end

  def test_sala_de_4_50_casa_montante_das_paredes_opostas
    t = L.trechos([[0, 0], [450, 0], [450, 300], [0, 300]], true)
    assert_equal [false, false, true, true], t.map { |x| x[:sobra_no_inicio] }
    assert_equal montantes_em_y(t, 0), montantes_em_y(t, 300)
    assert_equal [0.0, 100.0, 200.0, 300.0, 400.0, 450.0], montantes_em_y(t, 300)
  end

  def test_sala_desenhada_no_sentido_horario_tambem_casa
    t = L.trechos([[0, 0], [450, 0], [450, -300], [0, -300]], true)
    assert_equal montantes_em_y(t, 0), montantes_em_y(t, -300)
  end

  def test_teto_da_sala_de_4_50_cai_em_montante
    t = L.trechos([[0, 0], [450, 0], [450, 300], [0, 300]], true)
    assert_equal 0, L.pontas_sem_montante(450, 300, [true, true, true, true], L.eixos(t))
  end

  def test_parede_reta_continua_com_sobra_no_fim
    t = L.trechos([[450, 0], [0, 0]])
    refute t[0][:sobra_no_inicio]
    assert L.folhas_do(t[0])[:folhas].last[:meio]
  end

  def test_folhas_com_sobra_no_inicio
    f = L.folhas(250, inicio: true)[:folhas]
    assert_equal [[0.0, 50.0], [50.0, 100.0], [150.0, 100.0]], f.map { |x| [x[:x], x[:largura]] }
  end
end

class TestEditar < Minitest::Test
  def test_ler_lista
    assert_equal [300.0, 250.0], L.ler_lista("3; 2,5")
    assert_equal [300.0], L.ler_lista("3,00")
    assert_equal [300.0, 120.0], L.ler_lista("300cm;1,20 m")
    assert_nil L.ler_lista("3; x")
    assert_nil L.ler_lista("")
  end

  def test_retangulo
    assert L.retangulo?([[0, 0], [400, 0], [400, 300], [0, 300]])
    refute L.retangulo?([[0, 0], [400, 0], [300, 300], [0, 300]])
    refute L.retangulo?([[0, 0], [400, 0], [400, 300]])
  end

  def test_refazer_retangulo_mantem_canto_e_direcao
    novo = L.refazer_retangulo([[100, 100], [100, 500], [-200, 500], [-200, 100]], 500, 450)
    assert_equal [[100.0, 100.0], [100.0, 600.0], [-350.0, 600.0], [-350.0, 100.0]], novo
  end

  def test_refazer_pontos_da_parede_aberta
    novo = L.refazer_pontos([[0, 0], [300, 0], [300, 200]], [400, 250])
    assert_equal [[0.0, 0.0], [400.0, 0.0], [400.0, 250.0]], novo
    assert_raises(ArgumentError) { L.refazer_pontos([[0, 0], [300, 0]], [100, 200]) }
  end
end

class TestMedida < Minitest::Test
  def test_numero_sozinho_e_metro
    assert_equal 300.0, L.ler_medida("3")
    assert_equal 250.0, L.ler_medida("2,5")
    assert_equal 240.0, L.ler_medida("2.40")
  end

  def test_com_unidade
    assert_equal 300.0, L.ler_medida("300cm")
    assert_equal 300.0, L.ler_medida("300 cm")
    assert_equal 340.0, L.ler_medida("3,40 m")
    assert_equal 120.0, L.ler_medida("1200mm")
  end

  def test_invalido
    assert_nil L.ler_medida("")
    assert_nil L.ler_medida("abc")
    assert_nil L.ler_medida("0")
    assert_nil L.ler_medida("-2")
  end
end

class TestResumo < Minitest::Test
  def test_m2_da_sala_3x3_com_270
    t = L.trechos([[0, 0], [300, 0], [300, 300], [0, 300]], true)
    r = L.resumo(t, 270)
    assert_equal 12, r[:folhas_normais]
    assert_equal 0, r[:folhas_especiais]
    assert_equal 32.4, r[:m2]
  end

  def test_resumo_aponta_folha_especial
    r = L.resumo(L.trechos([[0, 0], [230, 0]]), 220)
    assert_equal 2, r[:folhas_normais]
    assert_equal 1, r[:folhas_especiais]
    assert_match(/folha especial de 30 cm/, r[:avisos].first)
  end

  def test_metros_formata_com_virgula
    assert_equal "2,70", L.metros(270)
    assert_equal "4,00", L.metros(400)
  end
end
