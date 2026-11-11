__attribute__((noinline))
int sub2(int x, int y)
{
    return x - y;
}

__attribute__((noinline))
int call_task(int x, int y, int z)
{
    int t = sub2(x, y);
    return t | z;
}
