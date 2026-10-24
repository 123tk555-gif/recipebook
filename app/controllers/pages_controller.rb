# 利用規約・プライバシーポリシー(ログインなしで見られる)
class PagesController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session

  def terms
  end

  def privacy
  end
end
