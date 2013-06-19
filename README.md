Xenograte Community Toolkit (XCT)
===

**Xenograte** is a platform that allows users to manage and orchestrate worker processes, and easily design 
flow of the data shared between them, within one server or across multiple servers.

**Xenograte Community Toolkit (XCT)** provides you with a Command Line Interface (CLI) and other required 
resources to build, test, and debug those worker processes, in [Ruby](http://www.ruby-lang.org/en/), on a 
single machine. You can then weave these worker processes together into powerful integrations and automations.

### Environment
* Tested on Mac OS X and Ubuntu
* Currently does NOT support Windows

### Prerequisites

* Redis 2.6 or newer http://redis.io/topics/quickstart
* Ruby 2.0 or newer http://www.ruby-lang.org/en/downloads/
* It is also recommended to install RVM with a Ruby https://rvm.io/

### To Install:

1. Download or Clone the repo: `git clone git@github.com:Nodally/xenograte-xct.git`
2. Change directory to the downloaded xenograte-xct project root.
3. make sure ruby gem 'bundler' is installed by using `gem list`. If it's not in the list, do a `gem install bundler` http://gembundler.com/
4. install required ruby gems by running `bundle install`

## Quick Start

#### in Xenograte, we call a worker process a *Xenode*
There are basically three types of worker processes (Xenodes). The first produces data and does not read messages (producer). The second that will read and write messages (producer/consumer), and the third that just reads messages (consumer).
Any xenode can be one of these three types. It just depends on what methods you implement in your xenode.

A simple producer/consumer xenode can look like the following:
```ruby
class EchoNode
  include XenoCore::NodeBase
  def process_message(msg)
    write_to_children(msg)
  end
end
```
The above is an echo xenode. All it does is write the received message to its children. Assigning children to a Xenode is done through [**orchestration**.](#in-xenograte-we-call-orchestration-of-the-worker-processes---xenoflow)
```ruby
class HelloWorldNode
  include XenoCore::NodeBase
  def process()
    msg = XenoCore::Message.new
    msg.data = "hello world"
    write_to_children(msg)
  end
end
```
The above is a hello world xenode as a producer example. It will write a message to its children every 1.5 seconds when the loop_delay value is set to 1.5. The message will have the value of "hello world" in its data.
```ruby
class DataWriterNode
  include XenoCore::NodeBase
  def process_message(msg)
    File.open(msg.context[:filename], 'w') do |f|
      f.write(msg.data)
    end
  end
end
```
The above is a data writer xenode. It looks at the inbound message's context for file_name to which to write the data. As a consumer it does not write messages to any children as it is a terminus node.
#### in Xenograte, we call orchestration of the worker processes - XenoFlow

XenoFlow is just a YAML file that defined the way the message flows between Xenodes.

In this XenoFlow, Xenode `n1` has one child `n2`, and `n2` has no child. 

The result, after you [run the XenoFlow](../../wiki/Command-Line-Interface-Usage#binxeno-run-xenoflow-run-a-xenoflow), whenever [`n1` receive a message](../../Command-Line-Interface-Usage#binxeno-write-message-write-a-message-to-a-xenode), `n1` will send the message to `n2` 

```yaml
---
xflow1:
  id: xflow1
  xenodes:
    n1:
      id: n1
      klass: EchoNode
      path: echo_node
      children:
      - n2
    n2:
      id: n2
      klass: EchoNode
      path: echo_node
      children: []
```

## Digging Deeper

Please [refers to our Wiki](../../wiki), it provides more in-depth knowledge on the following topics:

1. [**Xenode:** the worker process](../../wiki/Xenode)
2. [**XenoFlow:** orchestration of the worker processes](../../wiki/Xenoflow)
3. [**XenoMessage:** the messages flow between worker process](../../wiki/XenoMessage)
4. [**Command Line Interface (CLI) Usage**](../../wiki/Command-Line-Interface-Usage)


## Community

We invite you to follow the development and community updates on Xenograte:

- To raise a question, an idea, or want to start a discussion, go to the [Xenograte Community][23] linkedin group.
- Follow [@nodally][21] on Twitter.
- Read and subscribe to the [Nodally Blog][22].

[21]: http://twitter.com/nodally
[22]: http://blog.nodally.com
[23]: http://www.linkedin.com/groups/Xenograte-Community-5068501
