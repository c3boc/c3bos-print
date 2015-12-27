require 'escper'
require 'json'
require 'erb'
require 'ostruct'

printer = Escper::VendorPrinter.new :id => 1, :name => 'Drucker', :path => '/dev/usb/lp0', :copies => 1
print_engine = Escper::Printer.new 'local', printer



orders_json = '[
  {
    "location": "DDOS-Bar",
    "items": [
      {"name": "Club Mate", "amount": 5},
      {"name": "Premium Cola", "amount": 2},
      {"name": "Premium Bier", "amount": 2},
      {"name": "Flora Power", "amount": 3},
      {"name": "Fritz Orange", "amount": 1}
    ],
    "date": "2015-08-27 14:12"
  },
  {
    "location": "Foo-Bar",
    "items": [
      {"name": "Club Mate", "amount": 2},
      {"name": "Premium Bier", "amount": 10},
      {"name": "Flora Power", "amount": 3}
    ],
    "date": "2015-08-27 14:16"
  },
  {
    "location": "Bar-Bar",
    "items": [
      {"name": "Club Mate", "amount": 3},
      {"name": "Premium Bier", "amount": 1},
      {"name": "Fritz Orange", "amount": 1},
      {"name": "Flora Power", "amount": 8}
    ],
    "date": "2015-08-27 14:21"
  }
]'

template = "
====== BOC Order ======
Location: <%= location %>
Date: <%= date %>

==== Order Details ====
<% for item in items %>
* <%= item[\"amount\"] %>x <%= item[\"name\"] %>
<% end %>
=======================



"

orders = JSON.parse(orders_json)

orders.each do |order|
  orderstruct = OpenStruct.new(order)
  text = ERB.new(template).result(orderstruct.instance_eval { binding })
  print_engine.open
  print_engine.print 1, text
  print_engine.close
end
