// NanoHatOLED.swift
import Foundation
import I2C
import PNG

public enum AddressingMode{
    case NONE
    case HORIZONTAL_MODE
    case PAGE_MODE
}

struct ImageData {
    let data: [UInt8]
    let width: Int
    let height: Int
}

open class OLED {

    let device: I2CBusDevice?
    var address = 0x3c
    public var addressingMode: AddressingMode = .NONE

    public var OLED_Width			       = 128
    public var OLED_Height		           = 64
    public var OLED_Max_X                 = 128-1
    public var OLED_Max_Y                 = 64-1
                                                     
    public var OLED_Address               = UInt8(0x3d)
    public var OLED_Command_Mode          = UInt8(0x00)
    public var OLED_Data_Mode             = UInt8(0x40)
    public var OLED_Display_Off_Cmd       = UInt8(0xAE)
    public var OLED_Display_On_Cmd        = UInt8(0xAF)
    public var OLED_Normal_Display_Cmd    = UInt8(0xA6)
    public var OLED_Inverse_Display_Cmd   = UInt8(0xA7)
    public var OLED_Activate_Scroll_Cmd   = UInt8(0x2F)
    public var OLED_Dectivate_Scroll_Cmd  = UInt8(0x2E)
    public var OLED_Set_Brightness_Cmd    = UInt8(0x81)

    public var Scroll_Left                = UInt8(0x00)
    public var Scroll_Right               = UInt8(0x01)
    public var Scroll_2Frames             = UInt8(0x7)
    public var Scroll_3Frames             = UInt8(0x4)
    public var Scroll_4Frames             = UInt8(0x5)
    public var Scroll_5Frames             = UInt8(0x0)
    public var Scroll_25Frames            = UInt8(0x6)
    public var Scroll_64Frames            = UInt8(0x1)
    public var Scroll_128Frames           = UInt8(0x2)
    public var Scroll_256Frames           = UInt8(0x3)

    
    public init(_ bus: Int = 0, _ address: Int = 0x3c){
        self.address = address
        self.device = try? I2CBusDevice(portNumber: UInt8(bus))
    }

    public func setup(_ mode: AddressingMode = .HORIZONTAL_MODE){
        sendCommand(0xAE) // display OFF
        sendCommand(0x00) // set lower column address
        sendCommand(0x10) // set higher column address
        sendCommand(0x40) // set display start line
        sendCommand(0xB0) // set page address
        sendCommand(0x81) // contrast control
        sendCommand(0xCF) // 0~255
        sendCommand(0xA1) // set segment remap
        sendCommand(0xA6) // normal / reverse
        sendCommand(0xA8) // multiplex ratio
        sendCommand(0x3F) // duty = 1/64
        sendCommand(0xC8) // Com scan direction
        sendCommand(0xD3) // set display offset
        sendCommand(0x00) //
        sendCommand(0xD5) // set osc division
        sendCommand(0x80) //
        sendCommand(0xD9) // set pre-charge period
        sendCommand(0xF1) //
        sendCommand(0xDA) // set COM pins
        sendCommand(0x12) //
        sendCommand(0xDB) // set vcomh
        sendCommand(0x40) //
        sendCommand(0x8D) // set charge pump enable
        sendCommand(0x14) //
        sendCommand(0xAF) // displa
        sendCommand(OLED_Normal_Display_Cmd)
        switch mode {
        case .HORIZONTAL_MODE:
            setHorizontalMode()
        case .PAGE_MODE:
            setPageMode()
        default:
            print("mode \(mode) not recognized")
        }
    }
    
    
    public func setBrightness(_ brightness: UInt8){
        sendCommand(OLED_Set_Brightness_Cmd)
        sendCommand(brightness)
    }
    
    
    public func setHorizontalMode(){
        self.addressingMode = .HORIZONTAL_MODE
        sendCommand(0x20)          //set addressing mode
        sendCommand(0x00)          //set horizontal addressing mode
    }
    
    
    public func setPageMode(){
        self.addressingMode = .PAGE_MODE
        sendCommand(0x20)          //set addressing mode
        sendCommand(0x02)          //set page addressing mode
    }
    

    public func sendCommand(_ byte: UInt8){
        
        let _ = try? device?.write(toAddress: UInt8(address), data: [OLED_Command_Mode, byte])
    }

    public func sendData(_ byte: UInt8){
        
        let _ = try? device?.write(toAddress: UInt8(address), data: [OLED_Data_Mode, byte])
    }

    public func sendArrayData(_ array: [UInt8]){

        var arr = Array(array)
        
        let maxChunkSize = 31
        
        if (arr.count >= maxChunkSize){
        
        let div = arr.count / maxChunkSize

        for i in 0..<div {
            
            var chunk = Array(arr[maxChunkSize*i..<maxChunkSize*i+maxChunkSize])
            
            chunk.insert(OLED_Data_Mode, at: 0)

            let _ = try? device?.write(toAddress: UInt8(address),
                                              data: chunk,
                                              readBytes: UInt32(chunk.count))
            
        }

            if (arr.count % maxChunkSize > 0){
            
            var last = Array(arr[maxChunkSize*(arr.count / maxChunkSize)-1..<arr.count-1])
            
            last.insert(OLED_Data_Mode, at: 0)

            let _ = try? device?.write(toAddress: UInt8(address),
                                              data: last,
                                              readBytes: UInt32(last.count))
            }
            
        }else{
            
            arr.insert(OLED_Data_Mode, at: 0)
            let _ = try? device?.write(toAddress: UInt8(address),
                                              data: arr,
                                              readBytes: UInt32(arr.count))

        }

    }

    public func setTextXY(_ column: UInt8, _ row: UInt8){
        sendCommand(0xB0 + row)                  // set page address
        sendCommand(0x00 + (8*column & 0x0F))    // set column lower address
        sendCommand(0x10 + ((8*column>>4)&0x0F)) // set column higher address
    }

    public func putChar(_ char: String){
        // Ignore non-printable ASCII characters
        if let c = char.utf8.first, !(Int(c) < 32 || Int(c) > 127) {
            //print("Char=\(Int(c) - 32)")
            sendArrayData(BasicFont[Int(c) - 32])
            
        }else{
            sendArrayData(BasicFont[0])
        }
    }
    
    
    func putImage(_ path: String, sensitivity: UInt8 = 0){
        do {
            // load PNG Image as grayscale data
            let (pixels, (x: width, y: height)) = try PNG.v(path: path, of: UInt8.self)
            // convert to display format
            let array = packToGDDRAMFormat(ImageData(data: pixels, width: width, height: height), sensitivity: sensitivity)
            
            oled.sendArrayData(array)
            
        }catch{
            print("ERROR: Could Not Load Image! at path \(path)")
            return
        }
    }
    
    func packToGDDRAMFormat(_ imagedata: ImageData, sensitivity: UInt8 = 0) -> [UInt8] {
        var array = [UInt8](repeating: 0, count: imagedata.height / 8 * imagedata.width)
        var row = 0
        var column = 0
        for i in 0...imagedata.data.count{
            if (i > 0 && i % 8 == 0){
                var byte: UInt8 = 0x00
                for b:UInt8 in 0..<8 {
                    let bi = column+(Int(b)*imagedata.width)+(row * (8 * imagedata.width))
                    let bit : UInt8 = imagedata.data[bi] <= sensitivity ? 0 : 1
                    byte |= bit<<b
                }
                array[row * imagedata.width + column] = byte
                column += 1
            }
            if (i > 0 && i % (imagedata.height / 8 * imagedata.width) == 0){
                row += 1
                column = 0 // reset column
            }
        }
        return array
    }

    public let BasicFont: [[UInt8]] = [
    [0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00],//" "
    [0x00,0x00,0x5F,0x00,0x00,0x00,0x00,0x00],//"!"
    [0x00,0x00,0x07,0x00,0x07,0x00,0x00,0x00],//"""
    [0x00,0x14,0x7F,0x14,0x7F,0x14,0x00,0x00],//"#"
    [0x00,0x24,0x2A,0x7F,0x2A,0x12,0x00,0x00],//"$"
    [0x00,0x23,0x13,0x08,0x64,0x62,0x00,0x00],//"%"
    [0x00,0x36,0x49,0x55,0x22,0x50,0x00,0x00],//"&"
    [0x00,0x00,0x05,0x03,0x00,0x00,0x00,0x00],//"'"
    [0x00,0x1C,0x22,0x41,0x00,0x00,0x00,0x00],//"("
    [0x00,0x41,0x22,0x1C,0x00,0x00,0x00,0x00],//")"
    [0x00,0x08,0x2A,0x1C,0x2A,0x08,0x00,0x00],//"*"
    [0x00,0x08,0x08,0x3E,0x08,0x08,0x00,0x00],//"+"
    [0x00,0xA0,0x60,0x00,0x00,0x00,0x00,0x00],//","
    [0x00,0x08,0x08,0x08,0x08,0x08,0x00,0x00],//"-"
    [0x00,0x60,0x60,0x00,0x00,0x00,0x00,0x00],//"."
    [0x00,0x20,0x10,0x08,0x04,0x02,0x00,0x00],//"/"
    [0x00,0x3E,0x51,0x49,0x45,0x3E,0x00,0x00],//"0"
    [0x00,0x00,0x42,0x7F,0x40,0x00,0x00,0x00],//"1"
    [0x00,0x62,0x51,0x49,0x49,0x46,0x00,0x00],//"2"
    [0x00,0x22,0x41,0x49,0x49,0x36,0x00,0x00],//"3"
    [0x00,0x18,0x14,0x12,0x7F,0x10,0x00,0x00],//"4"
    [0x00,0x27,0x45,0x45,0x45,0x39,0x00,0x00],//"5"
    [0x00,0x3C,0x4A,0x49,0x49,0x30,0x00,0x00],//"6"
    [0x00,0x01,0x71,0x09,0x05,0x03,0x00,0x00],//"7"
    [0x00,0x36,0x49,0x49,0x49,0x36,0x00,0x00],//"8"
    [0x00,0x06,0x49,0x49,0x29,0x1E,0x00,0x00],//"9"
    [0x00,0x00,0x36,0x36,0x00,0x00,0x00,0x00],//":"
    [0x00,0x00,0xAC,0x6C,0x00,0x00,0x00,0x00],//";"
    [0x00,0x08,0x14,0x22,0x41,0x00,0x00,0x00],//"<"
    [0x00,0x14,0x14,0x14,0x14,0x14,0x00,0x00],//"="
    [0x00,0x41,0x22,0x14,0x08,0x00,0x00,0x00],//">"
    [0x00,0x02,0x01,0x51,0x09,0x06,0x00,0x00],//"?"
    [0x00,0x32,0x49,0x79,0x41,0x3E,0x00,0x00],//"@"
    [0x00,0x7E,0x09,0x09,0x09,0x7E,0x00,0x00],//"A"
    [0x00,0x7F,0x49,0x49,0x49,0x36,0x00,0x00],//"B"
    [0x00,0x3E,0x41,0x41,0x41,0x22,0x00,0x00],//"C"
    [0x00,0x7F,0x41,0x41,0x22,0x1C,0x00,0x00],//"D"
    [0x00,0x7F,0x49,0x49,0x49,0x41,0x00,0x00],//"E"
    [0x00,0x7F,0x09,0x09,0x09,0x01,0x00,0x00],//"F"
    [0x00,0x3E,0x41,0x41,0x51,0x72,0x00,0x00],//"G"
    [0x00,0x7F,0x08,0x08,0x08,0x7F,0x00,0x00],//"H"
    [0x00,0x41,0x7F,0x41,0x00,0x00,0x00,0x00],//"I"
    [0x00,0x20,0x40,0x41,0x3F,0x01,0x00,0x00],//"J"
    [0x00,0x7F,0x08,0x14,0x22,0x41,0x00,0x00],//"K"
    [0x00,0x7F,0x40,0x40,0x40,0x40,0x00,0x00],//"L"
    [0x00,0x7F,0x02,0x0C,0x02,0x7F,0x00,0x00],//"M"
    [0x00,0x7F,0x04,0x08,0x10,0x7F,0x00,0x00],//"N"
    [0x00,0x3E,0x41,0x41,0x41,0x3E,0x00,0x00],//"O"
    [0x00,0x7F,0x09,0x09,0x09,0x06,0x00,0x00],//"P"
    [0x00,0x3E,0x41,0x51,0x21,0x5E,0x00,0x00],//"Q"
    [0x00,0x7F,0x09,0x19,0x29,0x46,0x00,0x00],//"R"
    [0x00,0x26,0x49,0x49,0x49,0x32,0x00,0x00],//"S"
    [0x00,0x01,0x01,0x7F,0x01,0x01,0x00,0x00],//"T"
    [0x00,0x3F,0x40,0x40,0x40,0x3F,0x00,0x00],//"U"
    [0x00,0x1F,0x20,0x40,0x20,0x1F,0x00,0x00],//"V"
    [0x00,0x3F,0x40,0x38,0x40,0x3F,0x00,0x00],//"W"
    [0x00,0x63,0x14,0x08,0x14,0x63,0x00,0x00],//"X"
    [0x00,0x03,0x04,0x78,0x04,0x03,0x00,0x00],//"Y"
    [0x00,0x61,0x51,0x49,0x45,0x43,0x00,0x00],//"Z"
    [0x00,0x7F,0x41,0x41,0x00,0x00,0x00,0x00],//"["
    [0x00,0x02,0x04,0x08,0x10,0x20,0x00,0x00],//"\"
    [0x00,0x41,0x41,0x7F,0x00,0x00,0x00,0x00],//"]"
    [0x00,0x04,0x02,0x01,0x02,0x04,0x00,0x00],//"^"
    [0x00,0x80,0x80,0x80,0x80,0x80,0x00,0x00],//"_"
    [0x00,0x01,0x02,0x04,0x00,0x00,0x00,0x00],//"`"
    [0x00,0x20,0x54,0x54,0x54,0x78,0x00,0x00],//"a"
    [0x00,0x7F,0x48,0x44,0x44,0x38,0x00,0x00],//"b"
    [0x00,0x38,0x44,0x44,0x28,0x00,0x00,0x00],//"c"
    [0x00,0x38,0x44,0x44,0x48,0x7F,0x00,0x00],//"d"
    [0x00,0x38,0x54,0x54,0x54,0x18,0x00,0x00],//"e"
    [0x00,0x08,0x7E,0x09,0x02,0x00,0x00,0x00],//"f"
    [0x00,0x18,0xA4,0xA4,0xA4,0x7C,0x00,0x00],//"g"
    [0x00,0x7F,0x08,0x04,0x04,0x78,0x00,0x00],//"h"
    [0x00,0x00,0x7D,0x00,0x00,0x00,0x00,0x00],//"i"
    [0x00,0x80,0x84,0x7D,0x00,0x00,0x00,0x00],//"j"
    [0x00,0x7F,0x10,0x28,0x44,0x00,0x00,0x00],//"k"
    [0x00,0x41,0x7F,0x40,0x00,0x00,0x00,0x00],//"l"
    [0x00,0x7C,0x04,0x18,0x04,0x78,0x00,0x00],//"m"
    [0x00,0x7C,0x08,0x04,0x7C,0x00,0x00,0x00],//"n"
    [0x00,0x38,0x44,0x44,0x38,0x00,0x00,0x00],//"o"
    [0x00,0xFC,0x24,0x24,0x18,0x00,0x00,0x00],//"p"
    [0x00,0x18,0x24,0x24,0xFC,0x00,0x00,0x00],//"q"
    [0x00,0x00,0x7C,0x08,0x04,0x00,0x00,0x00],//"r"
    [0x00,0x48,0x54,0x54,0x24,0x00,0x00,0x00],//"s"
    [0x00,0x04,0x7F,0x44,0x00,0x00,0x00,0x00],//"t"
    [0x00,0x3C,0x40,0x40,0x7C,0x00,0x00,0x00],//"u"
    [0x00,0x1C,0x20,0x40,0x20,0x1C,0x00,0x00],//"v"
    [0x00,0x3C,0x40,0x30,0x40,0x3C,0x00,0x00],//"w"
    [0x00,0x44,0x28,0x10,0x28,0x44,0x00,0x00],//"x"
    [0x00,0x1C,0xA0,0xA0,0x7C,0x00,0x00,0x00],//"y"
    [0x00,0x44,0x64,0x54,0x4C,0x44,0x00,0x00],//"z"
    [0x00,0x08,0x36,0x41,0x00,0x00,0x00,0x00],//"{"
    [0x00,0x00,0x7F,0x00,0x00,0x00,0x00,0x00],//"|"
    [0x00,0x41,0x36,0x08,0x00,0x00,0x00,0x00],//"}"
    [0x00,0x02,0x01,0x01,0x02,0x01,0x00,0x00],//"~"
    [0x00,0x02,0x05,0x05,0x02,0x00,0x00,0x00]]//"˚"
}
