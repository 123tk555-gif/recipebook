# レシピの材料をまとめて買い物リストに追加する
class RecipeShoppingItemsController < ApplicationController
  def create
    recipe = Recipe.visible_to(current_user).find(params[:recipe_id])
    items = ShoppingItem.add_from_recipe!(user: current_user, recipe: recipe, servings: params[:servings])
    redirect_to shopping_items_path, notice: "「#{recipe.title}」の材料#{items.size}件を買い物リストに追加しました。"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to recipe_path(params[:recipe_id]), alert: e.record.errors.full_messages.to_sentence
  end
end
