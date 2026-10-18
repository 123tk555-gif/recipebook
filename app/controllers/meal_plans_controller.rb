class MealPlansController < ApplicationController
  def index
    @start = week_start
    plans = current_user.meal_plans.in_week(@start).includes(recipe: :user).order(:date, :slot, :id)
    @plans = plans.group_by { |plan| [ plan.date, plan.slot ] }
    @candidate_recipes = candidate_recipes
  end

  def create
    @plan = current_user.meal_plans.new(plan_params)
    @plan.recipe = Recipe.visible_to(current_user).find(plan_params[:recipe_id])
    if @plan.save
      redirect_to meal_plans_path(week: @plan.date), notice: "#{I18n.l(@plan.date, format: :long)}の#{@plan.slot_name}に「#{@plan.recipe.title}」を入れました。"
    else
      redirect_back_or_to meal_plans_path, alert: @plan.errors.full_messages.to_sentence
    end
  end

  def destroy
    plan = current_user.meal_plans.find(params[:id])
    plan.destroy!
    redirect_to meal_plans_path(week: plan.date), status: :see_other, notice: "献立から外しました。"
  end

  # その週の献立の材料を、まとめて買い物リストに追加する
  def add_to_shopping_list
    start = week_start
    plans = current_user.meal_plans.in_week(start).includes(recipe: :ingredients)
                        .select { |plan| plan.recipe.viewable_by?(current_user) && !plan.recipe.trashed? }
    count = 0
    ShoppingItem.transaction do
      plans.each { |plan| count += ShoppingItem.add_from_recipe!(user: current_user, recipe: plan.recipe, servings: plan.servings).size }
    end
    redirect_to shopping_items_path, notice: "この週の献立の材料#{count}件を買い物リストに追加しました。"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to meal_plans_path(week: start), alert: e.record.errors.full_messages.to_sentence
  end

  private
    def plan_params
      params.expect(meal_plan: [ :date, :slot, :servings, :recipe_id ])
    end

    # 週の始まり(月曜日)。日付が正しくないときは今週
    def week_start
      date = begin
        Date.iso8601(params[:week].to_s)
      rescue Date::Error
        Date.current
      end
      date.beginning_of_week(:monday)
    end

    # 献立に入れられるレシピ: 自分のレシピ + お気に入り(見られるものだけ)
    def candidate_recipes
      own = current_user.recipes.active
      favorite = current_user.favorite_recipes.merge(Recipe.visible_to(current_user))
      (own.to_a + favorite.to_a).uniq.sort_by(&:title)
    end
end
