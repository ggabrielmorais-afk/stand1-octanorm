# encoding: UTF-8
# ruby tests/test_autoupdate.rb  (Ruby comum, sem SketchUp)
require 'minitest/autorun'
require 'digest'
require_relative '../autoupdate'

U = STAND1::Octanorm::AutoUpdate
RBZ = "#{U::RAW}main/STAND1_Octanorm.rbz".freeze

class TestAutoUpdate < Minitest::Test
  def test_versao
    assert U.maior?("1.4.0", "1.3.0")
    assert U.maior?("1.10.0", "1.9.9")
    refute U.maior?("1.3.0", "1.3.0")
  end

  def test_so_aceita_rbz_do_repo
    assert U.url_do_repo?(RBZ)
    refute U.url_do_repo?("https://raw.githubusercontent.com/outro/repo/main/STAND1_Octanorm.rbz")
    refute U.url_do_repo?("#{U::RAW}main/../x.rbz")
    refute U.url_do_repo?("#{U::RAW}main/STAND1_Octanorm.exe")
  end

  def test_sha_obrigatorio
    sha = Digest::SHA256.hexdigest("conteudo")
    assert U.confere?("conteudo", sha)
    refute U.confere?("outro", sha)
    refute U.confere?("conteudo", "")
    assert_equal :invalida, U.avaliar({ "versao" => "9.0.0", "rbz" => RBZ }, "1.0.0")[0]
    assert_equal :nova, U.avaliar({ "versao" => "9.0.0", "rbz" => RBZ, "sha256" => sha }, "1.0.0")[0]
    assert_equal :em_dia, U.avaliar({ "versao" => "1.0.0", "rbz" => RBZ, "sha256" => sha }, "1.0.0")[0]
  end
end
