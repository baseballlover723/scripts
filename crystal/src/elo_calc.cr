record Probability, win : Float64, draw : Float64, loss : Float64

module Elo

  def self.calc_probs(rating1, rating2) : Probability
    as_white = calc_probs_white(rating1, rating2)
    as_black = calc_probs_black(rating1, rating2)

    win = (as_white.win + as_black.win) / 2.0
    draw = (as_white.draw + as_black.draw) / 2.0
    loss = (as_white.loss + as_black.loss) / 2.0
    Probability.new(win, draw, loss)
  end

  def self.calc_probs(rating1, rating2) : Probability
    as_white = calc_probs_white(rating1, rating2)
    as_black = calc_probs_black(rating1, rating2)

    win = (as_white.win + as_black.win) / 2.0
    draw = (as_white.draw + as_black.draw) / 2.0
    loss = (as_white.loss + as_black.loss) / 2.0
    Probability.new(win, draw, loss)
  end

  private def self.calc_probs_white(rating1, rating2) : Probability
    white_win = white_win_prob(rating1, rating2)
    black_win = black_win_prob(rating1, rating2)
    draw = draw_prob(white_win, black_win)
    Probability.new(white_win, draw, black_win)
  end

  private def self.calc_probs_black(rating1, rating2) : Probability
    white_win = white_win_prob(rating2, rating1)
    black_win = black_win_prob(rating2, rating1)
    draw = draw_prob(white_win, black_win)
    Probability.new(black_win, draw, white_win)
  end

  private def self.white_win_prob(wr, br)
    wcl = 40
    rm = (wr + br) / 2.0
    rd = wr - br
    wcv = rm <= 1200 ? 0.45 : 0.45 - 0.1 * (rm - 1200) * (rm - 1200) / (1200 * 1200)
    wll = -1492 + rm * 0.391
    wul = 1691 - rm * 0.428

    pw = 0.0
    if rd < wll
      pw = 0.0
    elsif wll <= rd <= wcl
      d1 = rd - wll
      d2 = wcl - wll
      pw = wcv * d1 * d1 / (d2 * d2)
    elsif wcl <= rd <= wul
      d1 = rd - wul
      d2 = wcl - wul
      pw = 1 - (1 - wcv) * d1 * d1 / (d2 * d2)
    elsif rd > wul
      pw = 1.0
    end
    pw
  end

  private def self.black_win_prob(wr, br)
    bcl = -80
    rm = (wr + br) / 2.0
    rd = wr - br
    bcv = rm <= 1200 ? 0.46 : 0.46 - 0.13 * (rm - 1200) ** 2 / (1200 ** 2)
    bll = -1753 + rm * 0.416
    bul = 1428 - rm * 0.388

    pw = 0.0
    if rd < bll
      pw = 1.0
    elsif bll <= rd <= bcl
      d1 = rd - bll
      d2 = bcl - bll
      pw = 1 - (1 - bcv) * d1 * d1 / (d2 * d2)
    elsif bcl <= rd <= bul
      d1 = rd - bul
      d2 = bcl - bul
      pw = bcv * d1 * d1 / (d2 * d2)
    elsif rd > bul
      pw = 0.0
    end
    pw
  end

  private def self.draw_prob(pw, pb)
    1 - pw - pb
  end
end
