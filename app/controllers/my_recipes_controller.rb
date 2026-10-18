class MyRecipesController < ApplicationController
  def index
    @recipes = current_user.recipes.active.with_attached_photo.newest_first
    @trashed_count = current_user.recipes.trashed.count
  end
end
