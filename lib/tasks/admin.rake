# 管理者を決める・外す
#   docker compose exec web bin/rails "admin:grant[someone@example.com]"
#   docker compose exec web bin/rails "admin:revoke[someone@example.com]"
#   docker compose exec web bin/rails admin:list
namespace :admin do
  desc "会員を管理者にする"
  task :grant, [ :email ] => :environment do |_t, args|
    user = User.find_by!(email_address: args[:email].to_s.strip.downcase)
    user.update!(admin: true)
    puts "#{user.display_name}(#{user.email_address})を管理者にしました"
  end

  desc "会員を管理者から外す"
  task :revoke, [ :email ] => :environment do |_t, args|
    user = User.find_by!(email_address: args[:email].to_s.strip.downcase)
    abort "最後の管理者は外せません" if user.last_admin?
    user.update!(admin: false)
    puts "#{user.display_name}(#{user.email_address})を管理者から外しました"
  end

  desc "管理者の一覧"
  task list: :environment do
    User.where(admin: true).find_each { |u| puts "#{u.display_name}(#{u.email_address})" }
  end
end
