# Recognize the current frame instead of saving per-window cycle state.
def near($a; $b): (($a - $b) | fabs) <= 3;
def target($ratio):
    ($bounds.w * $ratio | floor) as $w |
    {x: (if $side == "left" then $bounds.x else $bounds.x + $bounds.w - $w end | floor),
     y: ($bounds.y | floor), w: $w, h: ($bounds.h | floor)};
def matches($target):
    near(.frame.x; $target.x) and near(.frame.y; $target.y) and
    near(.frame.w; $target.w) and near(.frame.h; $target.h);

(if matches(target(1 / 2)) then 2 / 3
 elif matches(target(2 / 3)) then 1 / 3
 else 1 / 2 end) as $ratio |
target($ratio) | "abs:\(.w):\(.h)"
