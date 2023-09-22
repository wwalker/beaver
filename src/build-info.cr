class BuildInfo
  getter crystal_version : String
  getter llvm_version : String
  getter shards_version : String
  getter git_revision : String
  getter git_branch : String
  getter git_tag : String
  getter git_commit_date : String
  getter git_repo_clean : String
  getter build_time : String
  getter build_user : String
  getter build_args : String

  def initialize
    @crystal_version = {{ env("CRYSTAL_VERSION") }}
    @llvm_version = {{ env("LLVM_VERSION") }}
    @shards_version = {{ env("SHARDS_VERSION") }}
    @git_revision = {{ env("GIT_REVISION") }}
    @git_branch = {{ env("GIT_BRANCH") }}
    @git_tag = {{ env("GIT_TAG") }}
    @git_commit_date = {{ env("GIT_COMMIT_DATE") }}
    @git_repo_clean = {{ env("GIT_REPO_CLEAN") }}
    @build_time = {{ env("BUILD_TIME") }}
    @build_user = {{ env("BUILD_USER") }}
    @build_args = {{ env("BUILD_ARGS") }}
  end

  def version
    v = [] of String
    v << "#{@git_tag}" unless @git_tag.empty?
    v << "#{@git_branch}" if ! @git_branch.empty? && @git_tag.empty?
    v << "#{@git_revision}"
    v << "delta" if @git_repo_clean != "0"
    v.join(" - ")
  end

  def version_full
    v = [] of String
    v << "#{@git_tag}" if @git_tag
    v << "#{@git_revision}" if @git_revision
    v << "#{@git_branch}" if @git_branch
    v << "#{@git_commit_date}" if @git_commit_date
    v << "delta" if @git_repo_clean
    v << "#{@crystal_version}" if @crystal_version
    v << "#{@llvm_version}" if @llvm_version
    v << "#{@shards_version}" if @shards_version
    v << "#{@build_time}" if @build_time
    v << "#{@build_user}" if @build_user
    v << "#{@build_args}" if @build_args
    v.join(" - ")
  end
end

BUILD_INFO = BuildInfo.new
