require "test_helper"

class QuantityScalerTest < ActiveSupport::TestCase
  {
    [ "200g", 2 ] => "400g",
    [ "2合", Rational(1, 2) ] => "1合",
    [ "大さじ1", 2 ] => "大さじ2",
    [ "大さじ1と1/2", 2 ] => "大さじ3",
    [ "大さじ1", Rational(3, 2) ] => "大さじ1と1/2",
    [ "1/2個", 3 ] => "1と1/2個",
    [ "1/4本", 2 ] => "1/2本",
    [ "1.5カップ", Rational(1, 3) ] => "1/2カップ",
    [ "2〜3個", 2 ] => "4〜6個",
    [ "2~3個", 2 ] => "4~6個",
    [ "１２０ｍｌ", Rational(1, 2) ] => "60ml",
    [ "卵2個(Lサイズ)", Rational(1, 4) ] => "卵1/2個(Lサイズ)",
    [ "100g", Rational(1, 3) ] => "33.3g",
    [ "3個", Rational(2, 3) ] => "2個"
  }.each do |(quantity, ratio), expected|
    test "#{quantity} を #{ratio} 倍すると #{expected}" do
      assert_equal expected, QuantityScaler.scale(quantity, ratio)
    end
  end

  test "数字がない分量はそのまま" do
    assert_equal "少々", QuantityScaler.scale("少々", 2)
    assert_equal "適量", QuantityScaler.scale("適量", 3)
  end

  test "空・倍率1・計算できない数はそのまま" do
    assert_nil QuantityScaler.scale(nil, 2)
    assert_equal "", QuantityScaler.scale("", 2)
    assert_equal "大さじ1", QuantityScaler.scale("大さじ1", 1)
    assert_equal "1/0個", QuantityScaler.scale("1/0個", 2)
    assert_equal "0個", QuantityScaler.scale("0個", 2)
  end
end
