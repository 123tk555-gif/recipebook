# 材料の分量の文字列を、倍率に合わせて計算し直す。
#   QuantityScaler.scale("200g", 2)        #=> "400g"
#   QuantityScaler.scale("大さじ1と1/2", 2) #=> "大さじ3"
#   QuantityScaler.scale("1/2個", 3)       #=> "1と1/2個"
#   QuantityScaler.scale("2〜3個", 2)      #=> "4〜6個"
#   QuantityScaler.scale("少々", 2)        #=> "少々"(数字がないものはそのまま)
# 最初に出てくる数(範囲なら両端)だけを計算する。
module QuantityScaler
  # 分数(1/2)を先に試す。先に整数を試すと「1/2」の「1」だけを読んでしまうため
  NUMBER = %r{(?<fnum>\d+)/(?<fden>\d+)|(?<whole>\d+(?:\.\d+)?)(?:と(?<num>\d+)/(?<den>\d+))?}
  RANGE_SEPARATORS = /[~〜\-ー]/

  module_function

  def scale(quantity, ratio)
    return quantity if quantity.blank?

    ratio = ratio.to_r
    return quantity if ratio == 1

    text = quantity.unicode_normalize(:nfkc)
    first = text.match(NUMBER)
    return quantity unless first

    value = to_rational(first)
    return quantity if value.nil? || value.zero?

    head = text[0...first.begin(0)]
    rest = text[first.end(0)..]
    scaled = format(value * ratio)

    # 「2〜3個」のような範囲は、もう一方の数も計算する
    if (range = rest.match(/\A(?<sep>#{RANGE_SEPARATORS})(?<second>#{NUMBER})/o))
      second = to_rational(range[:second].match(NUMBER))
      if second
        return head + scaled + range[:sep] + format(second * ratio) + rest[range.end(0)..]
      end
    end

    head + scaled + rest
  end

  def to_rational(match)
    if match[:fnum]
      den = match[:fden].to_i
      return nil if den.zero?

      Rational(match[:fnum].to_i, den)
    else
      value = match[:whole].to_r
      if match[:num]
        den = match[:den].to_i
        return nil if den.zero?

        value += Rational(match[:num].to_i, den)
      end
      value
    end
  end

  # 整数ならそのまま。10未満で2分の1・3分の1・4分の1の単位なら分数(大さじ1と1/2 など)。
  # それ以外は小数第1位まで(100g の 1/3 は「33と1/3g」ではなく「33.3g」)
  def format(value)
    return value.to_i.to_s if value.denominator == 1

    if [ 2, 3, 4 ].include?(value.denominator) && value < 10
      whole, frac = value.numerator.divmod(value.denominator)
      fraction = "#{frac}/#{value.denominator}"
      return whole.zero? ? fraction : "#{whole}と#{fraction}"
    end

    rounded = value.to_f.round(1)
    rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
  end
end
