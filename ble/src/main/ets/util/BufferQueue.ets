export class BufferQueue<T> {
  private items: T[] = [];
  private dequeuePromise?: Promise<T | undefined>;
  private resolveDequeue?: (value: T | undefined) => void;

  enqueue(item: T): void {
    this.items.push(item);
    if (this.resolveDequeue) {
      this.resolveDequeue(this.dequeue());
      this.resetDequeuePromise();
    }
  }

  dequeue(): T | undefined {
    return this.items.shift();
  }

  getItemList(): T[] {
    return this.items;
  }

  setItemList(items: T[]): void {
    this.items = items;
  }

  async dequeueAsync(): Promise<T | undefined> {
    if (this.isEmpty()) {
      if (!this.dequeuePromise) {
        this.dequeuePromise = new Promise((resolve) => {
          this.resolveDequeue = resolve;
        });
      }
      return this.dequeuePromise;
    }
    return Promise.resolve(this.dequeue());
  }

  clear(): void {
    this.items = [];
    if (this.resolveDequeue) {
      this.resolveDequeue(undefined);
      this.resetDequeuePromise();
    }
  }

  isEmpty(): boolean {
    return this.items.length === 0;
  }

  private resetDequeuePromise(): void {
    this.dequeuePromise = undefined;
    this.resolveDequeue = undefined;
  }
}
