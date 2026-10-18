class ShoppingItemsController < ApplicationController
  before_action :set_item, only: %i[ update destroy ]

  def index
    @items = current_user.shopping_items.in_display_order.includes(:recipe)
    @item = current_user.shopping_items.new
  end

  # 手で1件追加する
  def create
    @item = current_user.shopping_items.new(params.expect(shopping_item: [ :name, :quantity ]))
    if @item.save
      redirect_to shopping_items_path, notice: "「#{@item.name}」を追加しました。"
    else
      @items = current_user.shopping_items.in_display_order.includes(:recipe)
      render :index, status: :unprocessable_entity
    end
  end

  # 「買った」のチェックを切り替える
  def update
    @item.update!(checked: ActiveModel::Type::Boolean.new.cast(params[:checked]))
    redirect_to shopping_items_path, status: :see_other,
                notice: @item.checked? ? "「#{@item.name}」を買ったものにしました。" : "「#{@item.name}」を買うものに戻しました。"
  end

  def destroy
    @item.destroy!
    redirect_to shopping_items_path, status: :see_other, notice: "「#{@item.name}」を消しました。"
  end

  def clear_checked
    count = current_user.shopping_items.where(checked: true).delete_all
    redirect_to shopping_items_path, status: :see_other, notice: "買ったもの#{count}件を消しました。"
  end

  def clear_all
    count = current_user.shopping_items.delete_all
    redirect_to shopping_items_path, status: :see_other, notice: "#{count}件をすべて消しました。"
  end

  private
    def set_item
      @item = current_user.shopping_items.find(params[:id])
    end
end
