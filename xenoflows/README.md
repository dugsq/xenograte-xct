## Xenoflows

This is where you put the XenoFlow YAML file.

### examples:

* __dropbox_to_gmail__
  * reading a file from your DropBox account and send the content to the specified email
  * please download the Xenodes into to your `/xenodes` folder:
    * [dropbox_reader_xenode](https://github.com/Nodally/dropbox_reader_xenode)
    * [gmail_sender_xenode](https://github.com/Nodally/gmail_sender_xenode)
  * to run: `bin/xeno run xenoflow -f examples/dropbox_to_gmail`
  * to stop: `bin/xeno stop xenoflow -f examples/dropbox_to_gmail`

* __rss_feeds_to_gmail__
  * monitoring the specified rss feeds and send an email whenever a new post appears
  * please download the Xenodes into to your `/xenodes` folder:
    * [dropbox_reader_xenode](https://github.com/Nodally/rss_feed_xenode)
    * [gmail_sender_xenode](https://github.com/Nodally/gmail_sender_xenode)
  * to run: `bin/xeno run xenoflow -f examples/rss_feeds_to_gmail`
  * to stop: `bin/xeno stop xenoflow -f examples/rss_feeds_to_gmail`

* __rss_feeds_to_sms__
  * monitoring the specified rss feeds and send an sms message whenever a new post appears
  * please download the Xenodes into to your `/xenodes` folder:
    * [dropbox_reader_xenode](https://github.com/Nodally/dropbox_reader_xenode)
    * [gmail_sender_xenode](https://github.com/Nodally/gmail_sender_xenode)
  * to run: `bin/xeno run xenoflow -f examples/rss_feeds_to_sms`
  * to stop: `bin/xeno stop xenoflow -f examples/sms_sender_xenode`

* __twitter_to_dropbox__
  * monitoring a term from Twitter and save the result into the DropBox
  * please download the Xenodes into to your `/xenodes` folder:
    * [twitter_search_xenode](https://github.com/Nodally/twitter_search_xenode)
    * [hash_to_csv_xenode](https://github.com/Nodally/hash_to_csv_xenode)
    * [dropbox_writer_xenode](https://github.com/Nodally/dropbox_writer_xenode)
  * to run: `bin/xeno run xenoflow -f examples/twitter_to_dropbox`
  * to stop: `bin/xeno stop xenoflow -f examples/twitter_to_dropbox`

* __twitter_to_sms__
  * monitoring a term from Twitter and send the result through sms
  * please download the Xenodes into to your `/xenodes` folder:
    * [twitter_search_xenode](https://github.com/Nodally/twitter_search_xenode)
    * [sms_sender_xenode](https://github.com/Nodally/sms_sender_xenode)
  * to run: `bin/xeno run xenoflow -f examples/twitter_to_sms`
  * to stop: `bin/xeno stop xenoflow -f examples/twitter_to_sms` 
