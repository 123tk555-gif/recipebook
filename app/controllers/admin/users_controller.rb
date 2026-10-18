# 管理者による会員の利用停止・解除
class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: %i[ suspend unsuspend ]

  def index
    @q = params[:q].to_s.strip
    users = User.order(created_at: :desc)
    if @q.present?
      pattern = "%#{User.sanitize_sql_like(@q)}%"
      users = users.where("email_address LIKE ? OR display_name LIKE ?", pattern, pattern)
    end
    @users = users.limit(100)
    @recipe_counts = Recipe.where(user_id: @users.map(&:id)).group(:user_id).count
  end

  def suspend
    if @user.admin?
      redirect_to admin_users_path, alert: "管理者は利用停止にできません。" and return
    end

    @user.suspend!
    redirect_to admin_users_path(q: params[:q]), status: :see_other, notice: "「#{@user.display_name}」を利用停止にしました。"
  end

  def unsuspend
    @user.unsuspend!
    redirect_to admin_users_path(q: params[:q]), status: :see_other, notice: "「#{@user.display_name}」の利用停止を解除しました。"
  end

  private
    def set_user
      @user = User.find(params[:id])
    end
end
