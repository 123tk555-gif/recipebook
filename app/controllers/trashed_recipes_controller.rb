class TrashedRecipesController < ApplicationController
  before_action :set_trashed_recipe, only: %i[ restore destroy ]

  def index
    @recipes = current_user.recipes.trashed.order(deleted_at: :desc)
  end

  def restore
    @recipe.restore!
    redirect_to @recipe, status: :see_other, notice: "元に戻しました。"
  end

  def destroy
    @recipe.destroy!
    redirect_to trashed_recipes_path, status: :see_other, notice: "完全に削除しました。"
  end

  def empty
    current_user.recipes.trashed.find_each(&:destroy!)
    redirect_to trashed_recipes_path, status: :see_other, notice: "ゴミ箱を空にしました。"
  end

  private
    def set_trashed_recipe
      @recipe = current_user.recipes.trashed.find(params[:id])
    end
end
