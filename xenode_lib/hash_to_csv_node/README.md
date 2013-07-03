### Overview ###
This Xenode will parse through hashes, converting the data into CSV format. Each incoming message with data should be an array with a hash inside for each row. If there was no readable data from the message, the Xenode will discard the message.

Config.yml must contain the default row and column delimiters. If you want to generate a header containing the column names on the first line then set `has_header` to true in config file.
