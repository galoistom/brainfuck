package main

import (
	"fmt"
	"os"
)

type Node interface {
	eval(*Tape) error
	isEmpty() bool
}

type bfAdd struct {
	num int
}

func (a bfAdd) eval(t *Tape) error {
	t.index[t.pointer] += uint8(a.num)
	return nil
}
func (a bfAdd) isEmpty() bool {
	return a.num == 0
}

type bfMove struct {
	times int
}

func (m bfMove) eval(t *Tape) error {
	t.pointer += m.times
	if t.pointer < 0 {
		return fmt.Errorf("too left: %d", t.pointer)
	} else if t.pointer >= len(t.index) {
		newCap := max(len(t.index)*2, t.pointer+1)
		temp := make([]byte, newCap)
		for i := range t.index {
			temp[i] = t.index[i]
		}
		t.index = temp
	}
	return nil
}
func (m bfMove) isEmpty() bool {
	return m.times == 0
}

type bfIn struct{}

func (bfIn) eval(t *Tape) error {
	fmt.Scanf("%c\n", &t.index[t.pointer])
	return nil
}
func (bfIn) isEmpty() bool { return false }

type bfOut struct{}

func (bfOut) eval(t *Tape) error {
	fmt.Printf("%c", t.index[t.pointer])
	return nil
}
func (bfOut) isEmpty() bool { return false }

type bfJump struct {
	target    int
	condition bool
}

func (bfJump) eval(t *Tape) error {
	return nil
}
func (bfJump) isEmpty() bool { return false }

type bfStart struct{}

func (bfStart) eval(t *Tape) error {
	return nil
}
func (bfStart) isEmpty() bool { return false }

type bfEnd struct{}

func (bfEnd) eval(t *Tape) error {
	return nil
}
func (bfEnd) isEmpty() bool { return false }

type Tape struct {
	index   []byte
	pointer int
}

func newTape() *Tape {
	return &Tape{make([]byte, 10), 0}
}

func preProcess(code []byte, err error) ([]Node, error) {
	if err != nil {
		return []Node{}, err
	}
	stack := []int{}
	current := Node(bfStart{})
	ast := []Node{}
	count := 0
	for _, c := range code {
		switch c {
		case '+':
			if c, ok := current.(bfAdd); ok {
				c.num++
				current = c
			} else {
				if !current.isEmpty() {
					count++
					ast = append(ast, current)
				}
				current = bfAdd{1}
			}
		case '-':
			if c, ok := current.(bfAdd); ok {
				c.num--
				current = c
			} else {
				if !current.isEmpty() {
					count++
					ast = append(ast, current)
				}
				current = bfAdd{-1}
			}
		case '<':
			if c, ok := current.(bfMove); ok {
				c.times--
				current = c
			} else {
				if !current.isEmpty() {
					count++
					ast = append(ast, current)
				}
				current = bfMove{-1}
			}
		case '>':
			if c, ok := current.(bfMove); ok {
				c.times++
				current = c
			} else {
				if !current.isEmpty() {
					count++
					ast = append(ast, current)
				}
				current = bfMove{1}
			}
		case ',':
			if !current.isEmpty() {
				count++
				ast = append(ast, current)
			}
			current = bfIn{}
		case '.':
			if !current.isEmpty() {
				count++
				ast = append(ast, current)
			}
			current = bfOut{}
		case '[':
			if !current.isEmpty() {
				count++
				ast = append(ast, current)
			}
			current = bfJump{-1, true}
			stack = append(stack, count)
		case ']':
			if !current.isEmpty() {
				count++
				ast = append(ast, current)
			}
			if len(stack) == 0 {
				return []Node{}, fmt.Errorf("failed to parse: too much ]")
			}
			t := stack[len(stack)-1]
			stack = stack[0 : len(stack)-1]
			if head, ok := ast[t].(bfJump); ok {
				head.target = count + 1
				ast[t] = head
				current = bfJump{t, false}
			} else {
				fmt.Errorf("should not get here")
			}
		}
	}
	if len(stack) != 0 {
		return []Node{}, fmt.Errorf("failed to parse: too much [")
	}
	return append(ast, current, bfEnd{}), nil
}

func process(ast []Node, e error) error {
	if e != nil {
		return e
	}
	current := 0
	tape := newTape()
	for {
		switch a := ast[current].(type) {
		case bfEnd:
			return nil
		case bfJump:
			if !a.condition || tape.index[tape.pointer] == 0 {
				current = a.target
			} else {
				current++
			}
		case bfAdd, bfMove, bfIn, bfOut, bfStart:
			err := a.eval(tape)
			if err != nil {
				return err
			}
			current++
		default:
			return fmt.Errorf("not impelemented")
		}
	}
	return nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("usage: brainfuck <file.bf> \n or brainfuck -e \"command\"")
		return
	}
	if os.Args[1] == "-e" {
		if len(os.Args) < 3 {
			fmt.Println("usage: brainfuck <file.bf> \n or brainfuck -e \"command\" ")
			return
		}
		err := process(preProcess([]byte(os.Args[2]), nil))
		if err != nil {
			fmt.Println("Failed process: ", err)
		}
		fmt.Println("")
		return
	}
	filename := os.Args[1]
	err := process(preProcess(os.ReadFile(filename)))
	if err != nil {
		fmt.Println("Failed process: ", err)
		return
	}
	fmt.Println("")
}
