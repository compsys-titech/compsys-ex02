__attribute__((noinline))
int add2(int x, int y)
{
    return x + y;
}

__attribute__((noinline))
int add_then_sub(int x, int y, int z)
{
    int t = add2(x, y);
    return t - z;
}
