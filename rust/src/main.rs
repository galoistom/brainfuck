use std::env;
use std::fs;
use std::io::{self, Read};

enum Bfnode {
    Bfadd(i8),
    Bfmove(i8),
    Bfin,
    Bfout,
    Bfloop(Vec<Bfnode>),
}

fn mod_256(a: i8, b: i8) -> i8 {
    (a as i16 + b as i16) as i8
}

fn parse_node(src: &[char]) -> Result<(Vec<Bfnode>, &[char]), String> {
    let mut ast: Vec<Bfnode> = Vec::new();
    let mut pos = 0;
    while pos < src.len() {
        match src[pos] {
            '+' => {
                if let Some(Bfnode::Bfadd(n)) = ast.last_mut() {
                    *n = mod_256(*n, 1);
                } else {
                    ast.push(Bfnode::Bfadd(1));
                }
                pos += 1;
            }
            '-' => {
                if let Some(Bfnode::Bfadd(n)) = ast.last_mut() {
                    *n = mod_256(*n, -1);
                } else {
                    ast.push(Bfnode::Bfadd(-1));
                }
                pos += 1;
            }
            '<' => {
                if let Some(Bfnode::Bfmove(n)) = ast.last_mut() {
                    *n = mod_256(*n, -1);
                } else {
                    ast.push(Bfnode::Bfmove(-1));
                }
                pos += 1;
            }
            '>' => {
                if let Some(Bfnode::Bfmove(n)) = ast.last_mut() {
                    *n = mod_256(*n, 1);
                } else {
                    ast.push(Bfnode::Bfmove(1));
                }
                pos += 1;
            }
            ',' => {
                ast.push(Bfnode::Bfin);
                pos += 1;
            }
            '.' => {
                ast.push(Bfnode::Bfout);
                pos += 1;
            }
            '[' => {
                let (inner_nodes, rest) = parse_node(&src[pos + 1..])?;
                if let Some(&']') = rest.first() {
                    let next_pos = pos + 1 + (src.len() - pos - 1 - rest.len()) + 1;
                    ast.push(Bfnode::Bfloop(inner_nodes));
                    pos = next_pos;
                } else {
                    return Err("Unmatched '[': bracket not closed".to_string());
                }
            }
            ']' => {
                return Ok((ast, &src[pos..]));
            }
            _ => {
                pos += 1;
            }
        }
    }
    Ok((ast, &[]))
}

fn clear_node(mut ast: Vec<Bfnode>) -> Vec<Bfnode> {
    let mut res = Vec::new();
    for node in ast.drain(..) {
        match node {
            Bfnode::Bfadd(0) => {}
            Bfnode::Bfmove(0) => {}
            Bfnode::Bfloop(l) => res.push(Bfnode::Bfloop(clear_node(l))),
            _ => res.push(node),
        }
    }
    res
}

fn parse(code: String) -> Result<Vec<Bfnode>, String> {
    match parse_node(&code.chars().collect::<Vec<char>>()) {
        Ok((res, _)) => Ok(clear_node(res)),
        Err(e) => Err(e),
    }
}

struct Tape {
    index: Vec<i8>,
    pointer: usize,
    capacity: usize,
}

impl Tape {
    fn new(capacity: usize) -> Self {
        Self {
            index: vec![0; capacity],
            pointer: 0,
            capacity: capacity,
        }
    }
    fn add(&mut self, num: i8) {
        self.index[self.pointer] = self.index[self.pointer] + num
    }
    fn movep(&mut self, num: i8) -> Result<(), String> {
        let p = (self.pointer as i64) + (num as i64);
        match usize::try_from(p) {
            Ok(res) => {
                while res >= self.capacity {
                    self.capacity *= 2;
                    self.index.resize(self.capacity, 0);
                }
                self.pointer = res;
            }
            Err(_) => return Err(format!("too left, position: {}", p)),
        }
        Ok(())
    }
}

fn eval(ast: &Vec<Bfnode>, t: &mut Tape) -> Result<(), String> {
    let mut position = 0;
    while position < ast.len() {
        match &ast[position] {
            Bfnode::Bfadd(n) => {
                position += 1;
                t.add(*n);
            }
            Bfnode::Bfmove(n) => {
                position += 1;
                t.movep(*n)?;
            }
            Bfnode::Bfin => {
                let mut buffer = [0; 1];
                match io::stdin().read_exact(&mut buffer) {
                    Ok(_) => {
                        t.index[t.pointer] = buffer[0] as i8;
                        position += 1
                    }
                    Err(_) => {
                        return Err("failed to read".to_string());
                    }
                }
            }
            Bfnode::Bfout => match u8::try_from(t.index[t.pointer]) {
                Ok(c) => {
                    print!("{}", c as char);
                    position += 1;
                }
                Err(_) => return Err("unable to convert to u8".to_string()),
            },
            Bfnode::Bfloop(l) => {
                while t.index[t.pointer] != 0 {
                    eval(&l, t)?;
                }
                position += 1;
            }
        }
    }
    Ok(())
}

fn main() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    let file_name = args[1].as_str();
    println!("{}", file_name);
    match fs::read_to_string(file_name) {
        Ok(code) => {
            eval(&parse(code)?, &mut Tape::new(10))?;
        }
        Err(_) => {
            return Err("failed to read".to_string());
        }
    }
    return Ok(());
}
