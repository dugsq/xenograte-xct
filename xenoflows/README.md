## Xenoflows

This is the folder where the Xenoflows should be located. We've added a few examples here for you to use as templates or to learn how to create your own Xenoflows.

### Examples:

* [__Dropbox_to_Gmail__](./examples/dropbox_to_gmail.yml)
 * read a file from your Dropbox account and send the content in an email through your Gmail account
  * please download the following Xenodes into to your `/xenodes` folder:
    * [dropbox_reader_xenode](https://github.com/Nodally/dropbox_reader_xenode)
    * [gmail_sender_xenode](https://github.com/Nodally/gmail_sender_xenode)
  * to run: `bin/xeno run xenoflow -f examples/dropbox_to_gmail`
  * to stop: `bin/xeno stop xenoflow -f examples/dropbox_to_gmail`


* [__RSS_Feeds_to_Gmail__](./examples/rss_feeds_to_gmail.yml)
  * monitor specific rss feeds and send new feeds in an email through your Gmail account
  * please download the following Xenodes into to your `/xenodes` folder:
    * [rss_feed_xenode](https://github.com/Nodally/rss_feed_xenode)
    * [gmail_sender_xenode](https://github.com/Nodally/gmail_sender_xenode)
  * to run: `bin/xeno run xenoflow -f examples/rss_feeds_to_gmail`
  * to stop: `bin/xeno stop xenoflow -f examples/rss_feeds_to_gmail`


* [__RSS_Feeds_to_SMS__](./examples/rss_feeds_to_sms.yml)
  * monitor specific rss feeds and send new feeds in an SMS message to your smartphone through your Twilio account
  * please download the following Xenodes into to your `/xenodes` folder:
    * [rss_feed_xenode](https://github.com/Nodally/rss_feed_xenode)
    * [sms_sender_xenode](https://github.com/Nodally/sms_sender_xenode)
  * to run: `bin/xeno run xenoflow -f examples/rss_feeds_to_sms`
  * to stop: `bin/xeno stop xenoflow -f examples/rss_feeds_to_sms`


* [__Twitter_to_Dropbox__](./examples/twitter_to_dropbox.yml)
  * perform a Twitter search and save the search result into a named CSV file on Dropbox
  * please download the following Xenodes into to your `/xenodes` folder:
    * [twitter_search_xenode](https://github.com/Nodally/twitter_search_xenode)
    * [hash_to_csv_xenode](https://github.com/Nodally/hash_to_csv_xenode)
    * [dropbox_writer_xenode](https://github.com/Nodally/dropbox_writer_xenode)
  * to run: `bin/xeno run xenoflow -f examples/twitter_to_dropbox`
  * to stop: `bin/xeno stop xenoflow -f examples/twitter_to_dropbox`


* [__Twitter_to_SMS__](./examples/twitter_to_sms.yml)
  * perform a Twitter search and send the search result in an SMS message to your smartphone through your Twilio account
  * please download the following Xenodes into to your `/xenodes` folder:
    * [twitter_search_xenode](https://github.com/Nodally/twitter_search_xenode)
    * [sms_sender_xenode](https://github.com/Nodally/sms_sender_xenode)
  * to run: `bin/xeno run xenoflow -f examples/twitter_to_sms`
  * to stop: `bin/xeno stop xenoflow -f examples/twitter_to_sms` 


* [__EDI_to_XML__](./examples/edi_to_xml.yml)
 * read a EDI file from a local directory, convert to XML format, and write an XML file to a local directory
  * please download the following Xenodes into to your `/xenodes` folder:
    * [file_reader_xenode](https://github.com/Nodally/file_reader_xenode)
    * [edi_to_xml_xenode](https://github.com/Nodally/edi_to_xml_xenode)
    * [file_writer_xenode](https://github.com/Nodally/file_writer_xenode)
  * to run: `bin/xeno run xenoflow -f examples/edi_to_xml`
  * to stop: `bin/xeno stop xenoflow -f examples/edi_to_xml`

