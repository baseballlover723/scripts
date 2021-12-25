require "ansi-escapes"

alias RowNumber = UInt16

class ProgressPrinter
  property io : IO
  property rows : RowNumber

  def initialize(rows : Int32, @io = STDOUT)
    initialize(rows.to_u16)
  end

  def initialize(@rows : RowNumber, @io = STDOUT)
    @io << "\n" * @rows
  end

  def print(row : RowNumber, content : String) : Void
    str = String.build do |str|
      str << AnsiEscapes::Cursor::SAVE_POSITION
      str << AnsiEscapes::Cursor.up(rows - row)
      str << AnsiEscapes::Erase::LINE
      str << content
      str << AnsiEscapes::Cursor::RESTORE_POSITION
    end
    io << str
  end
end
