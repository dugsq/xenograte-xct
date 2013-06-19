Xenograte Community Toolkit (XCT)
===

**Xenograte** is a platform that allows users to manage and orchestrate worker processes, and easily design 
flow of the data shared between them, within one server or across multiple servers.

**Xenograte Community Toolkit (XCT)** provides you with a Command Line Interface (CLI) and other required 
resources to build and debug those worker processes, in [Ruby](http://www.ruby-lang.org/en/), on your local 
machine. You can then weave these worker processes together into powerful integrations and automations.

### Environment
* Tested on Mac OSX and Ubuntu
* Currently NOT support Windows

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

#### in Xenograte, we call worker process - Xenode
The simplest Xenode can look like the following:
```ruby
class EchoNode
  include XenoCore::NodeBase
  def process_message(message)
    write_to_children(message)
  end
end
```
We will name this Xenode EchoNode. All it does is to pass the received message to it's children. To assigned a child to a Xenode, that is through **orchestration**

#### in Xenograte, we call orchestration of the worker processes - XenoFlow

XenoFlow is just a YAML file that defined the way the message flows between Xenodes.

In this XenoFlow, Xenode `n1` has one child `n2`, and `n2` has no child. 

The result, after you [run the XenoFlow](), whenever [`n1` receieve a message](), `n1` will send the message to `n2` 

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

Please [refers to our Wiki](../../wiki), it provides more in-depth knowledge on the follwoing topics:

1. [**Xenode:** the worker process](../../wiki/Xenode)
2. [**XenoFlow:** orchestration of the worker processes](../../wiki/Xenoflow)
3. [**XenoMessage:** the messages flow between worker process](../../wiki/XenoMessage)
4. [**Command Line Interface (CLI) Usage**](../../wiki/Command-Line-Interface-%28CLI%29-Usage)


## Community

We invite you to follow the development and community updates on Xenograte:

- To raise a question, an idea, or want to start a discussion, go to the [Xenograte Community][23] linkedin group.
- Follow [@nodally][21] on Twitter.
- Read and subscribe to the [Nodally Blog][22].

[21]: http://twitter.com/nodally
[22]: http://blog.nodally.com
[23]: http://www.linkedin.com/groups/Xenograte-Community-5068501
