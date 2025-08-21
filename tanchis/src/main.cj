package tanchis

import std.collection.*
import std.console.*
import std.math.*
import std.convert.*
import std.random.*
import std.sync.*
import std.time.*


const ROW: Int64 = 22 // 游戏区行数
const COL: Int64 = 42 // 游戏区列数


const UP: Int64 = 72 // 方向键：上
const DOWN: Int64 = 80 // 方向键：下
const LEFT: Int64 = 75 // 方向键：左
const RIGHT: Int64 = 77 // 方向键：右
const SPACE: Int64 = 32 // 暂停
const ESC: Int64 = 27 // 退出


struct GameStatus {
    static let KONG : Int64 = 0
    static let WALL : Int64 = 1 
    static let FOOD : Int64 = 2
    static let HEAD : Int64 = 3
    static let BODY : Int64 = 4
}


//仓颉与 C 互操作
@C
//用 COORD 结构体来指定光标的位置
 struct COORD {
    public var X: Int16 = 0         
    public var Y: Int16 = 0    

    public init(X : Int16,Y : Int16) {
        this.X = X
        this.Y = Y
    }            
}

@C   
//用于表示控制台光标信息的结构体    
struct CONSOLE_CURSOR_INFO {
    public var dwSize: UInt32 = 0           // C的DWORD是32位无符号整数，表示光标大小，范围为 1-100，表示光标占用单元格的百分比
    public var bVisible: Bool = false       // BOOL在Windows中为int (UInt32) ，表示光标可见性，TRUE 为可见，FALSE 为不可见
    
    public init(dwSize : UInt32,bVisible :Bool){
        this.dwSize = dwSize
        this.bVisible = bVisible
    }
}


// Windows API
foreign {
    // C 标准库函数声明
    func srand(seed: UInt32): Unit      // 返回void对应Unit
    func rand(): UInt32                // 返回int对应UInt32
    func Sleep(milliseconds: UInt32): Unit // 返回void对应Unit
    
    // Windows API 函数声明
    func GetStdHandle(nStdHandle: Int32): IntNative // HANDLE映射为IntNative
    // 修正后的SetConsoleCursorInfo函数声明
    func SetConsoleCursorInfo(hConsoleOutput: IntNative, lpCursorInfo : CONSOLE_CURSOR_INFO): Unit // 返回void
    func SetConsoleCursorPosition(hConsoleOutput: IntNative, coord: COORD): Unit // 返回void
    func SetConsoleTextAttribute(hConsoleOutput: IntNative, wAttributes: UInt16): Unit // 返回void
    func GetAsyncKeyState(vkKey: Int32): Int16 // 返回SHORT (Int16)
}


// 蛇头结构体
struct Snake {
    public var len: Int64  // 蛇身长度
    public var x: Int64   
    public var y: Int64    
    
    public init(len: Int64, x: Int64, y: Int64) {
        this.len = len
        this.x = x
        this.y = y
    }
}


// 蛇身结构体
struct Body {
    public var x: Int64  
    public var y: Int64 

    public init(x: Int64, y: Int64){
        this.x = x
        this.y = y
    }
}


//face二维数组内部存储的全为0，top-level处必须初始化，且不能采用流程控制语块
var face: Array<Array<Int64>> = Array< Array<Int64> > (
   ROW, { i =>  Array( COL,  { j => 0 }) }
)
var snake: Snake = Snake( 2 , COL / 2 , ROW / 2 ) 
var body: Array<Body> = Array<Body>(ROW * COL, {i => Body( 0 ,  0 )} )//蛇身最多长ROW*COL , 初始化蛇身坐标均为（0，0）
var grade: Int64  = 0


// 隐藏光标 
/*func HideCursor() {
    var curInfo = CONSOLE_CURSOR_INFO(1, false)  // 将大小从50改为1（更小更不可见）
    let handle = unsafe{GetStdHandle(-11)} // STD_OUTPUT_HANDLE为-11
    // 移除调试打印语句
    unsafe{SetConsoleCursorInfo(handle, curInfo)}
    // 移除调试打印语句
}*/


// 光标跳转
func CursorJump(x: Int64, y: Int64) {

    let pos = COORD( Int16( x * 2 ) , Int16 ( y ) ) // 直接使用数值运算
    let handle = unsafe{GetStdHandle(-11)}
    unsafe{SetConsoleCursorPosition(handle, pos)}
}


// 颜色设置
func color(c: Int64) {
    let handle = unsafe{GetStdHandle(-11)}
    unsafe{SetConsoleTextAttribute(handle, UInt16(c))}
}


// 初始化界面
func InitInterface() {

    color(6) // 土黄色
    for (i in 0..ROW) {
        for (j in 0..COL) {
            if (j == 0 || j == COL - 1 || i == 0 || i == ROW - 1) {
                face[i][j] = GameStatus.WALL
                CursorJump(j, i)
                print("■")
            } else {
                face[i][j] = GameStatus.KONG
            }
        }
    }
    color(7) // 白色
    CursorJump(0, ROW)
    print("当前得分: ${grade}")
}


// 初始化蛇
func InitSnake() {
     
    body[0] = Body( COL/2 - 1, ROW/2 ) 
    body[1] = Body( COL/2 - 2, ROW/2 ) // 初始化蛇头和蛇身
    
    face[snake.y][snake.x] = GameStatus.HEAD
    face[body[0].y][body[0].x] = GameStatus.BODY
    face[body[1].y][body[1].x] = GameStatus.BODY
}


// 随机生成食物
func RandFood() {
    var i: Int64 = 0
    var j: Int64 = 0
    while (true) { // 使用标准循环条件
        i = Int64(unsafe{rand()}) % ROW
        j = Int64(unsafe{rand()}) % COL
        if (face[i][j] == Int64( GameStatus.KONG )) { 
            break
        }
    }// 判断随机点是否为KONG
    
    face[i][j] = GameStatus.FOOD
    color(12) // 红色
    CursorJump(j, i)
    print("●")
    color(7)
}



// Additional foreign function declarations
foreign {
    func getch(): Int32                 
    func kbhit(): Int32                 
    func exit(status: Int32): Unit      
    func system(command: IntNative): Int32  
    func time(time: IntNative): IntNative
}

func cstr(s: String): IntNative {
    // 实现字符串到IntNative的转换
    // 这只是一个占位符 - 您需要实际的实现
    return IntNative(0)
}

// 判断函数 - 判断蛇头移动后的结果
func restartGame(): Unit {
    // 重置游戏变量
    // unsafe{system(cstr("echo -e '\033[?25l'"))}
    snake = Snake(2, COL / 2, ROW / 2)
    grade = 0
        for (i in 1..(ROW-1)) {
        for (j in 1..(COL-1)) {
            if (face[i][j] != GameStatus.WALL) {
                face[i][j] = GameStatus.KONG
                CursorJump(j, i)
                print("  ") // 用两个空格覆盖
            }
        }
    }
    // 重新初始化界面和蛇
    for (i in 0..ROW) {
        for (j in 0..COL) {
            face[i][j] = GameStatus.KONG
        }
    }
    
    InitInterface()
    InitSnake()
    RandFood()
    Game()
      //unsafe{system(cstr("echo -e '\033[?25h'"))} 
}


func JudgeFunc(x: Int64, y: Int64) {
    // 若蛇头即将到达的位置是食物，则得分
    if (face[snake.y + y][snake.x + x] == GameStatus.FOOD) {
        snake.len++ // 蛇身加长
        grade += 10 // 更新当前得分
        color(7) // 颜色设置为白色
        CursorJump(0, ROW)
        print("当前得分: ${grade}") // 重新打印当前得分
        RandFood() // 重新随机生成食物
    }
    // 若蛇头即将到达的位置是墙或者蛇身，则游戏结束
    else if (face[snake.y + y][snake.x + x] == GameStatus.WALL || face[snake.y + y][snake.x + x] == GameStatus.BODY) {
        unsafe{Sleep(1000)} // 留给玩家反应时间
    
    
    for (i in 0..ROW) {
        for (j in 0..COL) {
            CursorJump(j, i)
            print("  ") // 用两个空格覆盖
            face[i][j] = GameStatus.KONG // 重置所有位置状态为空
        }
    }
        
        
        color(7) // 颜色设置为白色
        
        
        CursorJump(2 * (COL / 3), ROW / 2 - 3)
       
       
        print("游戏结束，您的得分为: ${grade}")
        CursorJump(2 * (COL / 3), ROW / 2)
        print("GAME OVER")

        while (true) { // 询问玩家是否再来一局
            var ch: Int64 = 0
            CursorJump(2 * (COL / 3), ROW / 2 + 3)
            print("再来一局?(y/n):")
            ch = Int64(unsafe{getch()}) 
            if (ch == 121 || ch == 89) { // 'y' or 'Y'
                unsafe{system(cstr("cls"))}
                restartGame()
            }
            else if (ch == 110 || ch == 78) { // 'n' or 'N'
                CursorJump(2 * (COL / 3), ROW / 2 + 5)
                unsafe{exit(0)}
            }
        }
    }
}

// 打印蛇与覆盖蛇
func DrawSnake(flag: Int64) {
    if (flag == 1) { // 打印蛇
        color(10) // 颜色设置为绿色
        CursorJump(snake.x, snake.y)
        print("■") // 打印蛇头
        for (i in 0..(snake.len - 1)) {
            CursorJump(body[i].x, body[i].y)
            print("□") // 打印蛇身
        }
    }
    else { // 覆盖蛇
        if (body[snake.len - 1].x != 0) { // 防止len++后将(0, 0)位置的墙覆盖
            // 将蛇尾覆盖为空格即可
            CursorJump(body[snake.len - 1].x, body[snake.len - 1].y)
            print("  ")
        }
    }
}

// 移动蛇
func MoveSnake(x: Int64, y: Int64) {
    DrawSnake(0) // 先覆盖当前所显示的蛇
    face[body[snake.len - 1].y][body[snake.len - 1].x] = GameStatus.KONG // 蛇移动后蛇尾重新标记为空
    face[snake.y][snake.x] = GameStatus.BODY // 蛇移动后蛇头的位置变为蛇身
    
    // 蛇移动后各个蛇身位置坐标需要更新
var i: Int64 = snake.len - 1
while (i > 0) {
    body[i] = Body(body[i - 1].x, body[i - 1].y)
    i = i - 1  // 使用赋值语句代替 i--
}
    // 蛇移动后蛇头位置信息变为第0个蛇身的位置信息
    body[0] = Body(snake.x, snake.y)
    
    // 蛇头的位置更改
    snake.x = snake.x + x
    snake.y = snake.y + y
    
    DrawSnake(1) // 打印移动后的蛇
}

// 执行按键
func run(x: Int64, y: Int64) {
    var t: Int64 = 0
    while (true) {
        if (t == 0)
            {t = 3000 }// 这里t越小，蛇移动速度越快（可以根据次设置游戏难度）
        
        while (t != 0) {
           t = t - 1 // 计时器
            if (unsafe{kbhit()} != 0) // 若键盘被敲击，则退出循环
               {break} 
        }
        
        if (t == 0) { // 键盘未被敲击
            JudgeFunc(x, y) // 判断到达该位置后，是否得分与游戏结束
            MoveSnake(x, y) // 移动蛇
        }
        else { // 键盘被敲击
            break // 返回Game函数读取键值
        }
    }
}

// 游戏主体逻辑函数
func Game() {
    var n: Int64 = RIGHT // 开始游戏时，默认向右移动
    var tmp: Int64 = 0 // 记录蛇的移动方向
    
    // 用变量代替goto
    var firstRun: Bool = true
    
    while (true) {
        if (firstRun) {
            firstRun = false
            // 第一次进入循环先向默认方向前进
            n = RIGHT
        } else {
            n = Int64(unsafe{getch()})  // 读取键值
            
            // 在执行前，需要对所读取的按键进行调整
            if (n == UP || n == DOWN) { // 如果敲击的是"上"或"下"
                if (tmp != LEFT && tmp != RIGHT) { // 并且上一次蛇的移动方向不是"左"或"右"
                    n = tmp // 那么下一次蛇的移动方向设置为上一次蛇的移动方向
                }
            } else if (n == LEFT || n == RIGHT) { // 如果敲击的是"左"或"右"
                if (tmp != UP && tmp != DOWN) { // 并且上一次蛇的移动方向不是"上"或"下"
                    n = tmp // 那么下一次蛇的移动方向设置为上一次蛇的移动方向
                }
            } else if (n == SPACE || n == ESC || n  == 114 || n == 82) {
                // 这四个无需调整
            } else {
                n = tmp // 其他键无效，默认为上一次蛇移动的方向
            }
        }
        
        // 根据按键执行相应操作
        if (n == UP) { // 方向键：上
            run(0, -1) // 向上移动（横坐标偏移为0，纵坐标偏移为-1）
            tmp = UP // 记录当前蛇的移动方向
        } else if (n == DOWN) { // 方向键：下
            run(0, 1) // 向下移动（横坐标偏移为0，纵坐标偏移为1）
            tmp = DOWN // 记录当前蛇的移动方向
        } else if (n == LEFT) { // 方向键：左
            run(-1, 0) // 向左移动（横坐标偏移为-1，纵坐标偏移为0）
            tmp = LEFT // 记录当前蛇的移动方向
        } else if (n == RIGHT) { // 方向键：右
            run(1, 0) // 向右移动（横坐标偏移为1，纵坐标偏移为0）
            tmp = RIGHT // 记录当前蛇的移动方向
        } else if (n == SPACE) { // 暂停
            unsafe{system(cstr("pause>nul"))}// 暂停后按任意键继续
        } else if (n == ESC) { // 退出
            unsafe{system(cstr("cls"))} // 清空屏幕
            color(7) // 颜色设置为白色
            CursorJump(COL - 8, ROW / 2)
            print("  游戏结束  ")
            CursorJump(COL - 8, ROW / 2 + 2)
            unsafe{exit(0)}
        } else if (n == 114 || n == 82) { // 重新开始
            unsafe{system(cstr("cls"))}// 清空屏幕
            restartGame()// 重新执行主函数
        }
    }
}

main() {
    
    unsafe{
        unsafe{system(cstr("title 贪吃蛇"))}
        unsafe{system(cstr("mode con cols=84 lines=23"))}
    }
        // 显示开始界面
    // 显示开始界面的蛇图案
    //unsafe{system(cstr("echo -e '\033[?25l'"))} // 隐藏光标
    // 游戏代码

    // 绘制装饰边框
    color(14) // 黄色
    CursorJump(COL/2 - 13, ROW/2 )
    print("*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*")
    
    // 底部边框
    color(14) // 黄色
    CursorJump(COL/2 - 13, ROW/2 + 4)
    print("*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*")
    
    // 游戏标题
    color(11) // 淡蓝色
    CursorJump(COL/2 - 7, ROW/2 + 1)
    print("《 贪吃蛇游戏 》")
    
    // 在标题下方显示提示信息
    color(15) // 亮白色
    CursorJump(COL/2 - 6, ROW/2 + 2)
    print("游戏是否开始？")
    
    // 增加按键提示
    color(14) // 黄色
    CursorJump(COL/2 - 10, ROW/2 + 3)
    print("按 y 开始游戏，按 n 退出...")
    
    // 等待用户按 y 或 n
    var choice: Int64 = 0
    while (true) {
        choice = Int64(unsafe{getch()})
        if (choice == 121 || choice == 89) {      // 'y' 或 'Y'
            break                                 // 开始游戏
        } else if (choice == 110 || choice == 78) { // 'n' 或 'N'
            color(7)                              // 重置颜色为白色
            unsafe{exit(0)}                        // 退出程序
        }
        // 其他按键无效，继续等待
    }
    
    
    // 清屏后开始游戏
    for (i in 0..ROW) {
        for (j in 0..COL) {
            CursorJump(j, i)
            print("  ") // 用两个空格覆盖
        }
    }
   
  
    InitInterface() // 在函数中调用初始化逻辑
    InitSnake()
    unsafe{srand(UInt32(time(IntNative(0))))}//
    RandFood()
    Game() // 调用游戏函数
     //unsafe{system(cstr("echo -e '\033[?25h'"))} // 游戏结束时显示光标
    return 0
}