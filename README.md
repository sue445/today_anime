# これから放映されるアニメをポストするやつ
## Setup
```bash
bundle install
```

## Usage
```bash
export SLACK_WEBHOOK_URL=xxxxx

# optional
# export SLACK_CHANNEL=xxxxx

bundle exec ruby today_anime.rb
```

## 仕組み
* ブランチがpushされたら `#test` に投稿されます
  * [.gitlab-ci.yml](.gitlab-ci.yml) で設定
* スケジューラーからの実行はIncoming Webhookに設定されてるチャンネルに投稿されます
