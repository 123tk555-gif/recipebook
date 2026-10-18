class ApplicationMailer < ActionMailer::Base
  # 送信元は環境変数 MAIL_FROM で変える(本番は Amazon SES で認証したアドレス)
  default from: -> { ENV.fetch("MAIL_FROM", "noreply@example.com") }
  layout "mailer"
end
