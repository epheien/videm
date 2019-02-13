#!/usr/bin/env python
# -*- coding: utf-8 -*-

class Notifier:
    '''类似Linux内核的通知链机制'''
    # 对通知信息不感兴趣，也就是忽略
    DONE        = 0x0000
    # 通知信息被正确处理
    OK          = 0x0001
    # 内部使用，标识需要停止扩散通知
    STOP_MASK   = 0x8000
    # 有些事情出错了，将停止扩散通知
    BAD         = (STOP_MASK | 0x0002)
    # 通知被正确处理了，同时停止扩散通知
    STOP        = (STOP_MASK | OK)

    def __init__(self, name, data = None):
        self.name = name
        self.data = data
        # {'callback': callback, 'priority': priority, 'private': private}
        self.callbacks = []

    def Register(self, callback, priority, private = None):
        d = {}
        d['callback'] = callback
        d['priority'] = priority
        d['private'] = private
        idx = 0
        for idx, item in enumerate(self.callbacks):
            if priority > item['priority']:
                idx += 1
                break
        self.callbacks.insert(idx, d)
        return 0

    def Unregister(self, callback, priority):
        for idx, item in enumerate(self.callbacks):
            if item['callback'] is callback and item['priority'] == priority:
                del self.callbacks[idx]
                return 0
        return -1

    def CallChain(self, val, data = None, nr_to_call = -1):
        ret = self.DONE
        nr_calls = 0

        if data is None:
            data = self.data

        for item in self.callbacks:
            if not nr_to_call:
                break

            priv = item['private']
            ret = item['callback'](val, data, priv)
            nr_calls += 1

            # python 函数默认返回 None，当返回 0 即可
            if ret is None:
                ret = self.DONE

            if ((ret & self.STOP_MASK) == self.STOP_MASK):
                break

            nr_to_call -= 1

        return ret

def main(argv):
    def func1(val, data):
        print 'func1(%s, %s)' % (val, data)
        return Notifier.OK
    def func2(val, data):
        print 'func2(%s, %s)' % (val, data)
        return Notifier.DONE
    notif = Notifier('test', 'hello')
    notif.Register(func1, 1)
    notif.Register(func2, 0)
    assert notif.CallChain(222) == Notifier.OK
    assert notif.CallChain(222, 'world') == Notifier.OK

if __name__ == '__main__':
    import sys
    ret = main(sys.argv)
    if ret is None:
        ret = 0
    sys.exit(ret)
