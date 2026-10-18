class FavoritesController < ApplicationController
  before_action :set_recipe, only: %i[ create destroy ]

  # お気に入り一覧(非公開になった・ゴミ箱に入ったレシピは出さない)
  def index
    @recipes = current_user.favorite_recipes.merge(Recipe.visible_to(current_user))
                           .includes(:user, :tags).with_attached_photo
                           .order("favorites.created_at DESC")
  end

  def create
    current_user.favorites.find_or_create_by!(recipe: @recipe)
    redirect_back_or_to @recipe, notice: "お気に入りに追加しました。"
  rescue ActiveRecord::RecordNotUnique
    redirect_back_or_to @recipe, notice: "お気に入りに追加しました。"
  end

  def destroy
    current_user.favorites.find_by(recipe: @recipe)&.destroy!
    redirect_back_or_to @recipe, status: :see_other, notice: "お気に入りから外しました。"
  end

  private
    # 見られるレシピだけ。見られないものは「存在しない」扱い
    def set_recipe
      @recipe = Recipe.visible_to(current_user).find(params[:recipe_id])
    end
end
