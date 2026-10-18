class TagsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session

  def index
    @tags = Tag.popular(100)
  end
end
