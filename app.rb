#!/usr/bin/env ruby

require("bundler/setup")
require("csv")
Bundler.require(:default)

Dir[File.dirname(__FILE__) + '/lib/*.rb'].each { |file| require file }

# tracks user's game log and moves
text = []
moves = 0

get('/') do
  @index = true
  erb(:index)
end

get('/menu') do
  # Game Reset and Setup
  text = []
  moves = 0
  Room.all.each do |room|
    room.destroy
  end

  Item.all.each do |item|
    item.destroy
  end

  Note.all.each do |note|
    note.destroy
  end

  CSV.foreach('./lib/seeds/room_seeds.csv', headers: true) do |row|
    attributes = row.to_hash
    Room.create({
      name: attributes["name"].downcase,
      first_impression: attributes["first_impression"],
      description: attributes["description"],
      x_coordinate: attributes["x_coordinate"].to_i,
      y_coordinate: attributes["y_coordinate"].to_i,
      active: attributes["active"] == "1",
      solution_item: attributes["solution_item"] != nil ? attributes["solution_item"].downcase : nil,
      north_exit: attributes["north_exit"] == "1",
      east_exit: attributes["east_exit"] == "1",
      south_exit: attributes["south_exit"] == "1",
      west_exit: attributes["west_exit"] == "1",
      visited: attributes["visited"] == "1"
    })
  end

  CSV.foreach('./lib/seeds/items_seed.csv', headers: true) do |row|
    attributes = row.to_hash
    item_room = Room.where("name = ? and active = ?", attributes["room"].downcase, attributes["room_active"] == "1").first
    Item.create({
      name: attributes["name"].downcase,
      in_inventory: false,
      room_id: item_room != nil ? item_room.id : nil
    })
  end

  CSV.foreach('./lib/seeds/notes_seed.csv', headers: true) do |row|
    attributes = row.to_hash
    Note.create({
      room_name: attributes["room"].downcase,
      note_text: attributes["note_text"]
    })
  end
  erb(:menu)
end

get('/room/:name') do
  # gets a new room, either due to movement or solving a puzzle.
  results = Room.where("name = ? AND active = ?", params.fetch(:name), true)
  @room = results.length > 0 ? results.first : nil
  if @room
    text.push(@room.title_name)
    text.push(@room.look)
    text.push(@room.item ? "There is a #{@room.item.name} here." : nil)
    text.push(@room.note ? "There is a note here." : nil)
  end
  @moves = moves
  @text = text
  erb(:room)
end

post('/room/:name') do
  directions = ['n', 'north', 'e', 'east', 'w', 'west', 's', 'south']
  results = Room.where("name = ? AND active = ?", params.fetch(:name), true)
  if results.length > 0
    @room = results.first
    action = params.fetch(:action).downcase
    # tracks users moves and displays
    moves += 1
    @moves = moves
    # start of log for this turn
    text.push("")
    text.push("> " + action)
    if action.start_with?("look")
      # "look" action
      # grabs room.look, and notes if there are items or notes as well.
      text.push(@room.title_name)
      text.push(@room.look)
      text.push(@room.item ? "There is a #{@room.item.name} here." : nil)
      text.push(@room.note ? "There is a note here." : nil)
      @text = text
      erb(:room)
    elsif action.start_with?("move") || action.start_with?("go") || directions.include?(action)
      # "move" action
      # works if user types verb + direction, or just direction.
      # redirects to new room, or notifies about inaccessible direction.
      new_room = @room.move(action.split(" ")[1] || action)
      if new_room
        redirect '/room/' + new_room.name
      else
        text.push("You can't go that way.")
        @text = text
        erb(:room)
      end
    elsif action.start_with?("take")
      # "take" action
      # if user inputs name, or one word of name, of item in current room, the item is added to inventory
      result = @room.take(action.split(" ")[1..-1].join(" ") || "")
      if result
        text.push("Taken.")
      else
        text.push("You can't take that.")
      end
      @text = text
      erb(:room)
    elsif action.start_with?("use")
      # "use" action
      # room.use returns the 'success' version of a room if correct item is used
      success_room = @room.use(action.split(" ")[1..-1].join(" ") || "")
      if success_room
        redirect '/room/' + success_room.name
      else
        text.push("You can't use that here.")
        @text = text
        erb(:room)
      end
    elsif action.start_with?("read")
      # "read" action
      # returns the text of a room's note, or notifies user that there is no note to read
      text.push(@room.read != nil ? '"' + @room.read + '"' : "There is nothing to read here.")
      @text = text
      erb(:room)
    elsif action.start_with?("inventory")
      # "inventory" action
      # displays all items in inventory
      # does not count as a move
      moves -= 1
      @moves = moves
      if Item.inventory.any?
        Item.inventory.each do |item|
          text.push("* " + item.name)
        end
      else
        text.push('Inventory is empty.')
      end
      @text = text
      erb(:room)
    elsif action.start_with?("help")
      # "help" action
      # returns all commands user can enter
      # does not count as a move
      moves -= 1
      @moves = moves
      commands = ["Inventory", "Look", "Move [Cardinal Direction or N, E, S, W]", "Take [Item]", "Use [Inventory Item]", "Read [Note]", "Help"]
      text.push("Commands:")
      commands.each do |command|
        text.push ("* " + command)
      end
      @text = text
      erb(:room)
    else
      # Anything that is not recognized by the above code, game does not understand.
      text.push("I don't understand.")
      @text = text
      erb(:room)
    end
  end
end
