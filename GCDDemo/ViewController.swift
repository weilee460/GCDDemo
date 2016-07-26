//
//  ViewController.swift
//  GCDDemo
//
//  Created by ying on 16/7/21.
//  Copyright © 2016年 ying. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /**
     获取当前线程
     
     - returns: NSThread
     */
    private func getCurrentThread() -> NSThread {
        let currentThread = NSThread.currentThread()
        return currentThread
    }
    
    /**
     休眠当前的进程
     
     - parameter timer: 休眠时间 单位是秒
     */
    private func currentThreadSleep(timer: NSTimeInterval) -> Void
    {
        NSThread.sleepForTimeInterval(timer)
    }
    
    /**
     获取主队列，串行，更新UI
     
     - returns: dispatch_queue_t
     */
    private func getMainQueue() -> dispatch_queue_t {
        return dispatch_get_main_queue()
    }
    
    /**
     获取全局队列，并指定优先级
     
     - parameter priority: 优先级
     
     DISPATCH_QUEUE_PRIORITY_DEFAULT    默认
     DISPATCH_QUEUE_PRIORITY_HIGH       高
     DISPATCH_QUEUE_PRIORITY_LOW        低
     DISPATCH_QUEUE_PRIORITY_BACKGROUND 后台
     
     - returns: 全局队列
     */
    func getGlobalQueue(priority: dispatch_queue_priority_t = DISPATCH_QUEUE_PRIORITY_DEFAULT) -> dispatch_queue_t {
        return dispatch_get_global_queue(priority, 0)
    }
    
    /**
     创建concurrent队列
     
     - parameter label: 队列标记
     
     - returns: current queue
     */
    private func createConcurrentQueue(label: String) -> dispatch_queue_t {
        return dispatch_queue_create(label, DISPATCH_QUEUE_CONCURRENT)
    }
    
    /**
     创建串行队列
     
     - parameter label: 队列标记
     
     - returns: serial queue
     */
    private func createSerialQueue(label: String) -> dispatch_queue_t {
        return dispatch_queue_create(label, DISPATCH_QUEUE_SERIAL)
    }
    
    /**
     使用dispatch_sync在当前线程中，同步执行队列
     
     - parameter queue: 队列
     */
    func excuteQueuesUseSynchronization(queue: dispatch_queue_t) -> Void {
        for i in 0 ..< 3 {
            dispatch_sync(queue){
                [unowned self] in
                self.currentThreadSleep(1)
                print("当前执行线程： \(self.getCurrentThread())")
                print("执行 \(i)")
            }
            print("\(i) 执行完毕")
        }
        
        print("所有队列使用同步方式执行完毕")
    }
    
    /**
     使用dispatch_async在当前线程中，异步执行队列
     
     - parameter queue: 队列
     */
    func excuteQueueUseAsynchronization(queue: dispatch_queue_t) -> Void {
        let serialQueue = createSerialQueue("serialQueue")
        for i in 0 ..< 3 {
            dispatch_async(queue) {
                [unowned self] in
                self.currentThreadSleep(Double(arc4random()%3))
                let currentThread = self.getCurrentThread()
                dispatch_sync(serialQueue, { //这玩意，相当于一个同步锁
                    print("Sleep的线程\(currentThread)")
                    print("当前输出内容的线程\(self.getCurrentThread())")
                    print("执行\(i):\(queue)")
                })
            }
            print("\(i)添加完毕")
        }
        print("使用异步方式添加队列")
    }
    
    /**
     延迟执行
     
     - parameter time: 延迟执行的时间
     */
    func delayExcute(time: Double) -> Void {
        //dispatch_time计算延迟的相对时间，当设备休眠时，dispatch_time也睡眠了
        let delayTime: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(time * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, getGlobalQueue()) {
            print("执行线程：\(self.getCurrentThread()) \n dispatch_time: 延迟\(time)秒执行\n")
        }
        
        //dispatch_walltime用语计算绝对是件，而dispatch_walltime时根据挂钟来计算的时间，即使设备睡眠了，他也不回休眠
        let nowInterval = NSDate().timeIntervalSince1970
        var nowStruct = timespec(tv_sec: Int(nowInterval), tv_nsec: 0)
        let delayWalltime = dispatch_walltime(&nowStruct, Int64(time * Double(NSEC_PER_SEC)))
        dispatch_after(delayWalltime, getGlobalQueue()) {
            print("执行线程：\(self.getCurrentThread())\n dispatch_walltime: 延迟\(time)秒执行\n")
        }
        
    }
    
    /**
     全局队列的优先级关系
     */
    func globalQueuePriority() {
        let queueHeigh = getGlobalQueue(DISPATCH_QUEUE_PRIORITY_HIGH)
        let queueDefault = getGlobalQueue(DISPATCH_QUEUE_PRIORITY_DEFAULT)
        let queueLow = getGlobalQueue(DISPATCH_QUEUE_PRIORITY_LOW)
        let queueBackground = getGlobalQueue(DISPATCH_QUEUE_PRIORITY_BACKGROUND)
        
        dispatch_async(queueLow) {
            print("Low \(self.getCurrentThread())")
        }
        
        dispatch_async(queueBackground) {
            print("Background \(self.getCurrentThread())")
        }
        
        dispatch_async(queueDefault) {
            print("Default \(self.getCurrentThread())")
        }
        
        dispatch_async(queueHeigh) {
            print("Height \(self.getCurrentThread())")
        }
        
    }
    
    /**
     一组队列执行完毕后在执行完成后，需要执行其他东西时，可以使用dispatch_group来执行队列
     */
    func excuteGroupQueue() {
        print("任务组自动管理：")
        
        let concurrentQueue = createConcurrentQueue("cn.user.concurrent.queue")
        let group = dispatch_group_create()
        //将group与queue进行管理，并且自动执行
        for i in 0 ... 3 {
            dispatch_group_async(group, concurrentQueue) {
                self.currentThreadSleep(1)
                print("任务\(i)执行完毕")
            }
        }
        //任务组都执行完毕后会进行通知
        dispatch_group_notify(group, getMainQueue()) {
            print("任务组所有任务执行完毕！")
        }
        
        print("异步执行测试，不会阻塞当前线程")
    }
    
    /**
     使用enter与leave手动管理group与queue
     */
    func excuteGroupUseEnterAndLeave() {
        print("任务组手动管理：")
        let concurrentQueue = createConcurrentQueue("cn.concurrent.queue.group")
        let group = dispatch_group_create()
        
        //将group与queue进行手动关联和管理，并且自动执行
        for i in 1 ... 3 {
            dispatch_group_enter(group) //进入队列组
            dispatch_async(concurrentQueue, {
                self.currentThreadSleep(1)
                print("任务\(i)执行完毕")
                dispatch_group_leave(group)   //离开队列组
            })
        }
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER)  //阻塞当前线程，直到所有任务执行完毕
        print("任务组执行完毕")
        
        dispatch_group_notify(group, concurrentQueue) {
            print("手动管理的队列执行OK")
        }
    }
    
    /**
     信号量同步锁
     */
    func useSemaphoreLock() {
        let concurrentQueue = createConcurrentQueue("cn.user.concurrent.queue")
        //创建信号量
        let semaphoreLock = dispatch_semaphore_create(1)
        var testNumber = 0
        for index in 1 ... 3 {
            dispatch_async(concurrentQueue, {
                dispatch_semaphore_wait(semaphoreLock, DISPATCH_TIME_FOREVER) //上锁
                testNumber += 1
                self.currentThreadSleep(1.0)
                print(self.getCurrentThread())
                print("第\(index)次执行：testNumber = \(testNumber)")
                dispatch_semaphore_signal(semaphoreLock)   //解锁
            })
        }
        print("异步执行测试")
    }
    
    /**
     使用dispatch_apply来循环执行某些任务
     */
    func useDispatchApply() {
        print("循环多次执行并行队列")
        let concurrentQueue = createConcurrentQueue("cn.fengzi")
        //会阻塞当前线程，但concurrentQueue队列会在新的线程中执行
        dispatch_apply(2, concurrentQueue) { [unowned self] (index) in
            self.currentThreadSleep(Double(index))
            print("第\(index)次执行，\n \(self.getCurrentThread()) \n")
        }
        
        print("循环多次执行串行队列")
        let serialQueue = createSerialQueue("cn.fengzi.serial")
        //会阻塞当前线程，serialQueue队列在当前线程中执行
        dispatch_apply(2, serialQueue) { [unowned self] (index) in
            self.currentThreadSleep(Double(index))
            print("第\(index)次执行，\n \(self.getCurrentThread()) \n")
        }
    }
    
    /**
     暂停、唤醒队列
     */
    func queueSuspendAndResume() {
        let concurrentQueue = createConcurrentQueue("cn.fengzi.concurrent")
        dispatch_suspend(concurrentQueue) //将队列挂起
        dispatch_async(concurrentQueue) {
            print("执行任务")
        }
        
        currentThreadSleep(2)
        dispatch_resume(concurrentQueue) //唤醒挂起的队列
    }
    
    /**
     给任务添加barrier
     */
    func useBarrierAsync() {
        let concurrrentQueue = createConcurrentQueue("cn.concurrent.queue")
        
        for i in 0 ... 3 {
            dispatch_async(concurrrentQueue) {
                [unowned self] in
                self.currentThreadSleep(Double(i))
                print("第一批：\(i)\(self.getCurrentThread())")
            }
        }
        
        dispatch_barrier_async(concurrrentQueue) {
            print("第一批任务执行完毕后才会执行第二批任务 \(self.getCurrentThread())\n")
        }
        
        for i in 0 ... 3 {
            dispatch_async(concurrrentQueue) {
                [unowned self] in
                self.currentThreadSleep(Double(i))
                print("第二批：\(i)\(self.getCurrentThread())")
            }
        }
        
        print("异步执行测试")
    }
    
    /**
     使用dispatch_source创建源，类型为data_add
     */
    func useDispatchSourceAdd() {
        var sum = 0
        let concurrentQueue = getGlobalQueue()
        //创建source
        let dispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD, 0, 0, concurrentQueue)
        
        dispatch_source_set_event_handler(dispatchSource) {
            [unowned self] in
            print("source中所有的数相加的和等于\(dispatch_source_get_data(dispatchSource))")
            print("sum = \(sum) \n")
            sum = 0
            self.currentThreadSleep(0.3)
        }
        
        dispatch_resume(dispatchSource)
        
        for i in 1 ... 10 {
            sum += i
            dispatch_source_merge_data(dispatchSource, UInt(i))
            currentThreadSleep(0.1)
        }
    }
    
    /**
     使用dispatch_source创建源，类型为data_add
     */
    func useDispatchSourceOr() {
        var or = 0
        let concurrentQueue = getGlobalQueue()
        //创建source
        let dispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_OR, 0, 0, concurrentQueue)
        
        dispatch_source_set_event_handler(dispatchSource) {
            [unowned self] in
            print("source中所有的数相加的和等于\(dispatch_source_get_data(dispatchSource))")
            print("or = \(or) \n")
            or = 0
            self.currentThreadSleep(0.3)
        }
        
        dispatch_resume(dispatchSource)
        
        for i in 1 ... 10 {
            or |= i
            dispatch_source_merge_data(dispatchSource, UInt(i))
            currentThreadSleep(0.1)
        }
    }

    /**
     使用dispatch_source创建定时器
     */
    func useDispatchSourceTimer() {
        let concurrentQueue = getGlobalQueue()
        let source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, concurrentQueue)
        
        //设置间隔时间，从当前时间开始，允许偏差是0 ns
        dispatch_source_set_timer(source, DISPATCH_TIME_NOW, UInt64(1 * NSEC_PER_SEC), 0)
        var timeout = 10  //倒计时时间
        
        //设置要处理的事件，在我们上面创建的queue队列中执行
        dispatch_source_set_event_handler(source) {
            print(self.getCurrentThread())
            if timeout <= 0 {
                dispatch_source_cancel(source)
            } else {
                print("\(timeout)")
                timeout -= 1
            }
        }
        
        //倒计时结束的事件
        dispatch_source_set_cancel_handler(source) {
            print("倒计时结束")
        }
        
        //唤醒倒计时
        dispatch_resume(source)
    }
    
    

    //MARK: - Action
    /**
     同步执行串行队列
     
     - parameter sender: button
     */
    @IBAction func syncExcuteSerialQueue(sender: UIButton) {
        print("同步执行串行队列")
        excuteQueuesUseSynchronization(createSerialQueue("syn.serial.queue"))
    }
    
    /**
     同步执行并发队列
     
     - parameter sender: button
     */
    @IBAction func syncExcuteConcurrentQueue(sender: UIButton) {
        print("同步执行并发队列")
        excuteQueuesUseSynchronization(createConcurrentQueue("syn.concurrent.queue"))
    }
    
    /**
     异步执行串行队列
     
     - parameter sender: button
     */
    @IBAction func asyncExcuteSerialQueue(sender: UIButton) {
        print("异步执行串行队列")
        excuteQueueUseAsynchronization(createSerialQueue("asyn.serial.queue"))
    }
    
    /**
     异步执行concurrent队列
     
     - parameter sender: button
     */
    @IBAction func asyncExcuteConcurrentQueue(sender: UIButton) {
        print("异步执行concurrent队列")
        excuteQueueUseAsynchronization(createConcurrentQueue("aync.concurrent.queue"))
    }
    
    /**
     延迟执行，相对延时执行和绝对延时执行
     
     - parameter sender: button
     */
    @IBAction func delayExcuteAction(sender: UIButton) {
        print("延时执行")
        delayExcute(1.0)
    }
    
    //设置全局队列的优先级
    @IBAction func setGlobalQueuePriority(sender: UIButton) {
        print("设置全局队列的优先级")
        globalQueuePriority()
    }

    /**
     设置自定义的串行队列优先级
     
     - parameter sender: <#sender description#>
     */
    @IBAction func setUserQueuePriority(sender: UIButton) {
        print("创建自定义的高优先级串行队列")
        let serialQueueHigh = createSerialQueue("cn.user.serial.queue")
        dispatch_set_target_queue(serialQueueHigh, getGlobalQueue(DISPATCH_QUEUE_PRIORITY_HIGH))
    }
    
    /**
     自动执行任务组
     
     - parameter sender: button
     */
    @IBAction func autoExcuteGroupQueue(sender: UIButton) {
        print("自动执行任务组")
        excuteGroupQueue()
    }
    
    /**
     手动执行任务组
     
     - parameter sender: button
     */
    @IBAction func manualExcuteGroup(sender: UIButton) {
        print("手动执行任务组")
        excuteGroupUseEnterAndLeave()
    }
    
    /**
     使用信号量添加锁
     
     - parameter sender: button
     */
    @IBAction func useSemaphoreAddLocak(sender: UIButton) {
        print("使用信号量，添加锁")
        useSemaphoreLock()
    }
    
    /**
     使用dispatch_apply来循环执行某些任务
     
     - parameter sender: button
     */
    @IBAction func useApplyExcute(sender: UIButton) {
        print("使用dispatch_apply来循环执行某些任务")
        useDispatchApply()
    }
    
    /**
     挂起、唤醒队列
     
     - parameter sender: button
     */
    @IBAction func suspendAndResume(sender: UIButton) {
        print("暂停、唤醒队列")
        queueSuspendAndResume()
    }
    
    /**
     给任务添加barrier
     
     - parameter sender: button
     */
    @IBAction func useBarrierExcute(sender: UIButton) {
        print("使用barrier执行任务")
        useBarrierAsync()
    }
    
    /**
     使用dispatch_source创建源，类型为data_add
     
     - parameter sender: button
     */
    @IBAction func dispatchSourceAdd(sender: UIButton) {
        print("使用dispatch_source创建源，类型为data_add")
        useDispatchSourceAdd()
    }
    
    /**
     使用dispatch_source创建源，类型为data_or
     
     - parameter sender: button
     */
    @IBAction func dispatchSourceOr(sender: UIButton) {
        print("使用dispatch_source创建源，类型为data_or")
        useDispatchSourceOr()
    }
    
    /**
     使用dispatch_source创建定时器
     
     - parameter sender: button
     */
    @IBAction func dispatchSourceTimer(sender: UIButton) {
        print("使用dispatch_source创建定时器")
        useDispatchSourceTimer()
    }
}

