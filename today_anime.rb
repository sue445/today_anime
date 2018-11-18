ENV["ENVIRONMENT"] ||= "development"

Bundler.require(*[:default, ENV["ENVIRONMENT"]].compact)

require "yaml"

raise "SLACK_WEBHOOK_URL is required" unless ENV["SLACK_WEBHOOK_URL"]

SLACK_WEBHOOK_URL = ENV["SLACK_WEBHOOK_URL"]

END_HOUR = 4
END_MINUTE = 0

Time.zone = "Tokyo"

class Syobocalite::Program
  # Slackに投稿するための文言に整形する
  # @return [String]
  def format
    start_time = st_time.strftime("%H:%M")

    elements = []
    elements << "#{start_time}〜【#{ch_name}】#{title}"

    if story_number >= 1 || !sub_title.blank?
      str = ""
      str << "第#{story_number}話" if story_number >= 1
      str << "「#{sub_title}」" unless sub_title.blank?
      elements << str
    end

    elements << display_flag unless display_flag.blank?

    unless prog_comment.blank?
      elements << "※#{prog_comment}"
    end

    elements.join(" ")
  end

  # flagを表示用に整形する
  def display_flag
    str = ""
    str << "【新】" if new?
    str << "【終】" if final?
    str << "【再】" if re_air?
    str
  end

  # 注
  def remark?
    flag & 0x01 != 0
  end

  # 新
  def new?
    flag & 0x02 != 0
  end

  # 終
  def final?
    flag & 0x04 != 0
  end

  # 再
  def re_air?
    flag & 0x08 != 0
  end

  private

  # @see https://sites.google.com/site/syobocal/spec/proginfo-flag
  def flag
    return @flag if @flag

    client = SyoboiCalendar::Client.new
    response = client.list_programs(title_id: tid, program_id: pid)

    @flag = response.resources.first.flag
  end
end

# @param title       [String]
# @param channel_ids [Array<Integer>]
def perform(title:, channel_ids:)
  # 実行時の時間（分以下は切り捨て）〜翌4:00までのアニメを取得する
  # 例) 19:19に実行されたら19:00〜翌4:00で取得する
  start_at = Time.current.change(min: 0)
  end_at = (start_at + 1.day).change(hour: END_HOUR, minute: END_MINUTE)

  puts "now: #{Time.current}"
  puts "start_at: #{start_at}"
  puts "end_at: #{end_at}"

  programs = Syobocalite.search(start_at: start_at, end_at: end_at)

  programs.select! { |program| channel_ids.include?(program.ch_id) } unless channel_ids.empty?

  programs.sort_by! { |program| [program.st_time, program.ch_name, program.title] }

  message = programs.each_with_object("") do |program, str|
    str << "- #{program.format}\n"
  end

  message = "今日のアニメは無いようです" if message.blank?

  post_slack(username: "今日のアニメ（#{title}）", message: message)
end

# @param username [String]
# @param message  [String]
def post_slack(username:, message:)
  notifier = Slack::Notifier.new(SLACK_WEBHOOK_URL)

  # c.f. https://api.slack.com/methods/chat.postMessage
  options = {
    username: username,
    icon_emoji: ":tv:",
    unfurl_links: false,
  }

  options[:channel] = ENV["SLACK_CHANNEL"] if ENV["SLACK_CHANNEL"]

  puts <<~MSG
    -----------
    #{Time.current}
    [username] #{username}

    [message]
    #{message}
    -----------
  MSG

  notifier.ping(message, options)
end

config = YAML.load_file("#{__dir__}/config.yml")

config["areas"].each do |hash|
  perform(title: hash["title"], channel_ids: hash["channel_ids"])
end
