# 管理者によるレシピの非公開・解除
class Admin::RecipesController < Admin::BaseController
  before_action :set_recipe

  def hide
    @recipe.hide!
    redirect_back_or_to recipe_path(@recipe), status: :see_other, notice: "「#{@recipe.title}」を非公開にしました。"
  end

  def unhide
    @recipe.unhide!
    redirect_back_or_to recipe_path(@recipe), status: :see_other, notice: "「#{@recipe.title}」の非公開を解除しました。"
  end

  private
    def set_recipe
      @recipe = Recipe.find(params[:id])
    end
end
