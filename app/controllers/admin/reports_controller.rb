class Admin::ReportsController < Admin::BaseController
  def index
    @status = Report.statuses.key?(params[:status]) ? params[:status] : "open"
    @counts = Report.group(:status).count
    @reports = Report.where(status: @status).includes(:reporter, :handled_by, recipe: :user)
                     .newest_first.limit(100)
  end

  # 対応する: レシピを非公開にする / 問題なしとする。
  # 同じレシピへの未対応の通報も、まとめて同じ結果にする
  def update
    report = Report.find(params[:id])
    decision = params[:decision]
    unless %w[hidden dismissed].include?(decision)
      redirect_to admin_reports_path, alert: "対応の種類が正しくありません。" and return
    end

    Report.transaction do
      report.recipe.hide! if decision == "hidden" && !report.recipe.hidden?
      Report.status_open.where(recipe: report.recipe)
            .update_all(status: Report.statuses[decision], handled_by_id: current_user.id,
                        handled_at: Time.current, updated_at: Time.current)
    end
    message = decision == "hidden" ? "「#{report.recipe.title}」を非公開にしました。" : "「#{report.recipe.title}」の通報を「問題なし」にしました。"
    redirect_to admin_reports_path, status: :see_other, notice: message
  end
end
