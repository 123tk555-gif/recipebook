class RecipesController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]
  before_action :resume_session, only: %i[ index show ]
  before_action :set_own_recipe, only: %i[ edit update destroy ]

  def index
    @recipes = Recipe.visible_to(nil).includes(:user, :tags).with_attached_photo.newest_first.limit(50)
  end

  def show
    @recipe = Recipe.includes(:ingredients, :steps, :tags, :user).find(params[:id])
    raise ActiveRecord::RecordNotFound unless @recipe.viewable_by?(current_user)
  end

  def new
    @recipe = current_user.recipes.new(servings: 2)
    build_blank_rows(@recipe)
  end

  def create
    @recipe = current_user.recipes.new(recipe_params)
    if @recipe.save
      redirect_to @recipe, notice: "レシピを登録しました。"
    else
      build_blank_rows(@recipe)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    build_blank_rows(@recipe)
  end

  def update
    if @recipe.update(recipe_params)
      redirect_to @recipe, notice: "レシピを更新しました。"
    else
      build_blank_rows(@recipe)
      render :edit, status: :unprocessable_entity
    end
  end

  # 削除はゴミ箱に移す(30日以内なら元に戻せる)
  def destroy
    @recipe.trash!
    redirect_to my_recipes_path, status: :see_other,
                notice: "ゴミ箱に移しました。#{Recipe::TRASH_DAYS}日以内なら元に戻せます。"
  end

  private
    # 自分のレシピだけ。他人のレシピは「存在しない」ものとして扱う
    def set_own_recipe
      @recipe = current_user.recipes.active.find(params[:id])
    end

    def build_blank_rows(recipe)
      (3 - recipe.ingredients.reject(&:marked_for_destruction?).size).times { recipe.ingredients.build }
      (3 - recipe.steps.reject(&:marked_for_destruction?).size).times { recipe.steps.build }
    end

    def recipe_params
      params.expect(recipe: [
        :title, :description, :cooking_minutes, :servings, :published, :tag_list, :photo, :remove_photo,
        ingredients_attributes: [ [ :id, :name, :quantity, :position, :_destroy ] ],
        steps_attributes: [ [ :id, :body, :position, :_destroy ] ]
      ])
    end
end
