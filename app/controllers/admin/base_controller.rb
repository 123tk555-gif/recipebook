# 管理画面の共通部分。管理者以外には、管理画面があること自体を見せない(404)
class Admin::BaseController < ApplicationController
  before_action :require_admin

  private
    def require_admin
      raise ActiveRecord::RecordNotFound unless current_user&.admin?
    end
end
