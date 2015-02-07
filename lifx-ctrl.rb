#!/usr/bin/env ruby

require 'lifx'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} options"
  opts.on('-o', '--off', 'switch light off') do
    options[:off] = true
  end
  opts.on('-i', '--info', 'get info') do
    options[:info] = true
  end
  opts.on('-c color', '--color color', 'set color (red|green|blue|white|orange|yellow|cyan|purple|pink)') do |color|
    options[:color] = color
  end
  opts.on('-h hue', '--hue hue', 'set hue (0..360)') do |hue|
    options[:hue] = hue.to_i
  end
  opts.on('-l label', '--label label', 'set label of device to be controlled') do |label|
    options[:label] = label
  end
  opts.on('-s saturation', '--saturation saturation', 'set saturation (0..1)') do |saturation|
    options[:saturation] = saturation.to_f
  end
  opts.on('-b brightness', '--brightness brightness', 'set brightness (0..1)') do |brightness|
    options[:brightness] = brightness.to_f
  end
  opts.on('-k kelvin', '--kelvin kelvin', 'set kelvin (2500..9000)') do |kelvin|
    options[:kelvin] = kelvin.to_f
  end
  opts.on_tail('--help', 'show this message') do
    puts opts
    exit
  end
end.parse!

begin
  client = LIFX::Client.lan
  client.discover!
rescue LIFX::Client::DiscoveryTimeout => e
  puts "no lifx bulb found: #{e.message}"
  exit 1
end

targets = if options[:label]
  light = client.lights.with_label(options[:label])
  unless light
    puts "no lifx bulb found with label '#{options[:label]}'"
    exit 2
  end

  targets = LIFX::LightCollection.new(context: light.context)
else
  client.lights
end

case
when options[:off]
  targets.turn_off
when options[:info]
  targets.each do |l|
    puts l.label
    %w(power tags temperature latency).each do |x|
      puts "#{x}: #{l.send(x)}"
    end
    %w(hue brightness saturation kelvin).each do |x|
      puts "#{x}: #{l.color.send(x)}"
    end
  end
else
  targets.turn_on

  color = case
  when options[:color]
    begin
      LIFX::Color.send(options[:color])
    rescue NoMethodError => e
      puts 'unknown color'
      exit 3
    end
  when options[:hue]
    LIFX::Color.new(options[:hue], 1, 1, LIFX::Colors::DEFAULT_KELVIN)
  when targets.lights.length == 1
    targets.lights.first.color
  else
    LIFX::Color.white
  end

  color = color.with_brightness(options[:brightness]) if options[:brightness]
  color = color.with_saturation(options[:saturation]) if options[:saturation]
  color = color.with_kelvin(options[:kelvin]) if options[:kelvin]

  targets.set_color(color)
end

client.flush
