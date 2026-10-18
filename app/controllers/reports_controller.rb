# 会員がレシピを通報する
class ReportsController < ApplicationController
  before_action :set_recipe
  rate_limit to: 10, within: 1.hour, only: :create,
             with: -> { redirect_to recipe_path(params[:recipe_id]), alert: "通報が多すぎます。しばらくしてからやり直してください。" }

  def new
    @report = @recipe.reports.new
  end

  def create
    @report = @recipe.reports.new(params.expect(report: [ :reason, :detail ]).merge(reporter: current_user))
    if @report.save
      redirect_to @recipe, notice: "通報を受け付けました。管理者が確認します。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    # 通報できるのは、公開中のレシピだけ
    def set_recipe
      @recipe = Recipe.publicly_visible.find(params[:recipe_id])
    end
end
